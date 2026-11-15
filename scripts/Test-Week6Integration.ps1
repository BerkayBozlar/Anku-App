param(
    [string]$ApiBaseUrl = 'http://localhost:5080',
    [switch]$CheckSources,
    [string]$FailureApiBaseUrl = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
[xml]$project = Get-Content -LiteralPath (Join-Path $repoRoot 'backend/AnkuApp.Api/AnkuApp.Api.csproj') -Raw
$settings = Get-Content -LiteralPath (Join-Path $env:APPDATA "Microsoft/UserSecrets/$($project.Project.PropertyGroup.UserSecretsId)/secrets.json") -Raw | ConvertFrom-Json
$script:passed = 0
Add-Type -AssemblyName System.Net.Http
$http = [System.Net.Http.HttpClient]::new()
$http.Timeout = [TimeSpan]::FromSeconds(40)

function Secret([string]$Key) {
    $value = $settings.$Key
    if (-not $value) { $value = $settings; foreach ($part in $Key.Split(':')) { $value = $value.$part } }
    if (-not $value) { throw "Eksik yerel ayar: $Key" }
    return [string]$value
}
function Check([bool]$Condition, [string]$Label) {
    if (-not $Condition) { throw "KONTROL BASARISIZ: $Label" }
    $script:passed++
    Write-Host "[OK] $Label"
}
function Api([string]$Method, [string]$Path, [string]$Token = '', $Payload = $null, [int]$Expected = 200, [string]$Base = $ApiBaseUrl) {
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $Base.TrimEnd('/') + $Path)
    try {
        if ($Token) { $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token) }
        if ($null -ne $Payload) { $request.Content = [System.Net.Http.StringContent]::new(($Payload | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8, 'application/json') }
        $response = $http.SendAsync($request).GetAwaiter().GetResult()
        try {
            $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if ([int]$response.StatusCode -ne $Expected) { throw "$Method $Path : beklenen $Expected, gelen $([int]$response.StatusCode). $content" }
            if ($content) { return ($content | ConvertFrom-Json) }
        } finally { $response.Dispose() }
    } finally { $request.Dispose() }
}
function CalendarState {
    return @(Api GET '/api/content-sync' $admin.accessToken | Where-Object { $_.id -eq 'academic-calendar' }) | Select-Object -First 1
}

$ids = @()
try {
    $admin = Api POST '/api/auth/login' -Payload @{email='admin@ankuapp.test';password=(Secret 'Seed:AdminPassword')}
    $student = Api POST '/api/auth/login' -Payload @{email='ogrenci@ankuapp.test';password=(Secret 'Seed:StudentPassword')}
    $manager = Api POST '/api/auth/login' -Payload @{email='kulup@ankuapp.test';password=(Secret 'Seed:ClubPassword')}
    foreach ($path in @('/api/academic-calendar', '/api/academic-calendar/years', '/api/academic-calendar/1')) {
        Api GET $path -Expected 401 | Out-Null
        Check $true "Takvim okumasinda JWT gerekli: $path"
    }
    Api POST '/api/academic-calendar/refresh' -Expected 401 | Out-Null
    Check $true 'Oturumsuz kaynak yenilenemez'
    $tag = [Guid]::NewGuid().ToString('N')
    $scope = "Week6-$tag"
    $payload = @{academicYear='2098-2099';scope=$scope;term='Fall';title="Week6 Range $tag";description='Temporary test record';startDate='2098-09-14';endDate='2098-09-20';sourceName='Ankara University';sourceUrl='https://oidb.ankara.edu.tr/';sourcePage=1}
    $first = Api POST '/api/academic-calendar' $admin.accessToken $payload -Expected 201
    $ids += $first.id
    Check ($first.isManual -and $first.uniqueKey.Length -eq 64 -and $first.startDate -eq '2098-09-14') 'Yoneticinin kaydi gun bazli tarihler ve kaynak bilgisiyle saklanir'
    $sameDay = $payload.Clone(); $sameDay.title = "Week6 Day $tag"; $sameDay.startDate = '2098-09-25'; $sameDay.endDate = '2098-09-25'; $sameDay.term = 'Spring'
    $second = Api POST '/api/academic-calendar' $admin.accessToken $sameDay -Expected 201
    $ids += $second.id
    Check ($second.startDate -eq $second.endDate) 'Tek gunluk akademik tarih desteklenir'
    Api POST '/api/academic-calendar' $admin.accessToken $payload -Expected 409 | Out-Null
    Api PUT "/api/academic-calendar/$($second.id)" $admin.accessToken $payload -Expected 409 | Out-Null
    Check $true 'Ayni baslik, yil, kapsam, donem ve tarihler tekrar kaydedilmez'
    foreach ($user in @($student, $manager)) {
        $detail = Api GET "/api/academic-calendar/$($first.id)" $user.accessToken
        $years = @(Api GET '/api/academic-calendar/years' $user.accessToken)
        Check ($detail.title -eq $payload.title -and $years -contains '2098-2099') 'Ogrenci/kulup yetkilisi ayrinti ve mevcut akademik yillari okuyabilir'
        Api POST '/api/academic-calendar' $user.accessToken $payload -Expected 403 | Out-Null
        Api PUT "/api/academic-calendar/$($first.id)" $user.accessToken $payload -Expected 403 | Out-Null
        Api DELETE "/api/academic-calendar/$($first.id)" $user.accessToken -Expected 403 | Out-Null
        Api POST '/api/academic-calendar/refresh' $user.accessToken -Expected 403 | Out-Null
        Check $true 'Takvim yonetimi ve yenileme yalniz yoneticiye acik'
    }
    $filter = "academicYear=2098-2099&scope=$scope"
    $all = Api GET "/api/academic-calendar?$filter&pageSize=100" $student.accessToken
    Check ($all.totalCount -eq 2 -and $all.items[0].id -eq $first.id) 'Akademik yil/kapsam filtresi ve tarih siralamasi'
    $overlap = Api GET "/api/academic-calendar?$filter&from=2098-09-16&to=2098-09-16" $student.accessToken
    Check ($overlap.totalCount -eq 1 -and $overlap.items[0].id -eq $first.id) 'Devam eden tarih araligi ara gun sorgusunda kaybolmaz'
    foreach ($day in @('2098-09-14', '2098-09-20')) {
        $boundary = Api GET "/api/academic-calendar?$filter&from=$day&to=$day" $student.accessToken
        Check ($boundary.totalCount -eq 1) 'Baslangic ve bitis gunleri filtreye dahildir'
    }
    $fall = Api GET "/api/academic-calendar?$filter&term=Fall" $student.accessToken
    Check ($fall.totalCount -eq 1 -and $fall.items[0].id -eq $first.id) 'Donem filtresi'
    $one = Api GET "/api/academic-calendar?$filter&page=1&pageSize=1" $student.accessToken
    $two = Api GET "/api/academic-calendar?$filter&page=2&pageSize=1" $student.accessToken
    Check ($one.totalCount -eq 2 -and $one.items.Count -eq 1 -and $one.items[0].id -ne $two.items[0].id) 'Kararli sayfalama ve toplam sayi'
    $empty = Api GET "/api/academic-calendar?$filter&from=2098-10-01&to=2098-10-02" $student.accessToken
    Check ($empty.totalCount -eq 0 -and $empty.items.Count -eq 0 -and $empty.message) 'Veri olmayan aralik acik bos durum doner'
    foreach ($query in @('academicYear=2026-2028','academicYear=bad','term=Unknown','page=0','pageSize=101','page=2147483647&pageSize=100','from=2026-11-20&to=2026-11-01')) {
        Api GET "/api/academic-calendar?$query" $student.accessToken -Expected 400 | Out-Null
        Check $true "Gecersiz sorgu reddedilir: $query"
    }
    foreach ($case in @(@{academicYear='2026-2028'},@{term='Unknown'},@{title=' '},@{scope=' '},@{startDate=$null},@{endDate='2098-09-13'},@{endDate='2100-01-01'},@{sourcePage=0},@{sourceUrl='https://ankara.edu.tr.evil.test/a'})) {
        $bad = $payload.Clone(); foreach ($key in $case.Keys) { $bad[$key] = $case[$key] }
        Api POST '/api/academic-calendar' $admin.accessToken $bad -Expected 400 | Out-Null
        Api PUT "/api/academic-calendar/$($first.id)" $admin.accessToken $bad -Expected 400 | Out-Null
        Check $true 'Takvim ekleme ve guncelleme dogrulamasi'
    }
    $payload.title += ' Updated'
    Api PUT "/api/academic-calendar/$($first.id)" $admin.accessToken $payload -Expected 204 | Out-Null
    $updated = Api GET "/api/academic-calendar/$($first.id)" $student.accessToken
    Check ($updated.title -eq $payload.title -and $updated.uniqueKey -eq $first.uniqueKey) 'Guncelleme kayit kimligini ve anahtarini korur'
    Api GET '/api/academic-calendar/2147483647' $student.accessToken -Expected 404 | Out-Null
    Check $true 'Olmayan takvim kaydi 404 doner'

    if ($CheckSources) {
        $refresh = Api POST '/api/academic-calendar/refresh' $admin.accessToken
        Check ($refresh.success -and $refresh.imported -ge 40) 'Resmi PDF genel takvimin iki donemini okur'
        $source = Api GET '/api/academic-calendar?academicYear=2026-2027&pageSize=100' $admin.accessToken
        $sourceIds = @($source.items | Where-Object { -not $_.isManual } | Select-Object -ExpandProperty id)
        $again = Api POST '/api/academic-calendar/refresh' $admin.accessToken
        $after = Api GET '/api/academic-calendar?academicYear=2026-2027&pageSize=100' $student.accessToken
        $afterIds = @($after.items | Where-Object { -not $_.isManual } | Select-Object -ExpandProperty id)
        Check ($again.success -and $source.totalCount -eq $after.totalCount -and -not (Compare-Object $sourceIds $afterIds)) 'Yenileme kayitlari cogaltmaz ve kaynak kayit kimliklerini degistirmez'
        $sourceEntries = @($after.items | Where-Object { -not $_.isManual })
        Check (@($sourceEntries | Where-Object { $_.sourcePage -notin @(1,2) }).Count -eq 0) 'Kaynak sayfalari korunur; ozel fakulteler genel takvime karismaz'
        $fallCount = @($sourceEntries | Where-Object { $_.term -eq 'Fall' }).Count
        $springCount = @($sourceEntries | Where-Object { $_.term -eq 'Spring' }).Count
        Check ($fallCount -gt 0 -and $springCount -gt 0) 'Guz ve bahar donemleri ayridir'
        $manual = Api GET "/api/academic-calendar/$($first.id)" $student.accessToken
        Check ($manual.title -eq $payload.title -and $manual.isManual) 'Elle girilen kayit yenileme sonrasinda okunabilir'
        $state = CalendarState
        Check ($state.lastSuccessAt -and -not $state.lastError) 'Takvim son basari durumu ortak kaynak durumunda gorunur'
    }
    if ($FailureApiBaseUrl) {
        $before = CalendarState
        $beforePage = Api GET '/api/academic-calendar?academicYear=2026-2027&pageSize=100' $student.accessToken
        $failure = Api POST '/api/academic-calendar/refresh' $admin.accessToken -Expected 503 -Base $FailureApiBaseUrl
        Check ([bool]$failure.message) 'Bozuk PDF kaynagi 503 ve acik hata mesaji doner'
        $afterPage = Api GET '/api/academic-calendar?academicYear=2026-2027&pageSize=100' $student.accessToken
        $state = CalendarState
        Check ($beforePage.totalCount -eq $afterPage.totalCount -and $state.lastError -and $state.lastSuccessAt -eq $before.lastSuccessAt) 'Kaynak hatasinda mevcut takvim ve son basari zamani korunur'
        $manual = Api GET "/api/academic-calendar/$($first.id)" $student.accessToken
        Check ($manual.title -eq $payload.title) 'Kaynak bozukken manuel veri de okunabilir'
        if ($CheckSources) { Api POST '/api/academic-calendar/refresh' $admin.accessToken | Out-Null }
    }
}
finally {
    foreach ($id in $ids) {
        Api DELETE "/api/academic-calendar/$id" $admin.accessToken -Expected 204 | Out-Null
        Api GET "/api/academic-calendar/$id" $admin.accessToken -Expected 404 | Out-Null
    }
    $http.Dispose()
    Write-Host '[OK] Yalniz gecici takvim kayitlari temizlendi; resmi veri korundu'
}
Write-Host "Tamamlandi: $script:passed entegrasyon kontrolu basarili."
