param(
    [string]$ApiBaseUrl = 'http://localhost:5080',
    [string]$PortalBaseUrl = 'http://localhost:5025',
    [switch]$CheckSources,
    [string]$FailureApiBaseUrl = ''
)

# API/MVC ve PostgreSQL acik olmali. Gecici kayitlar finally blogunda temizlenir.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
[xml]$project = Get-Content -LiteralPath (Join-Path $repoRoot 'backend/AnkuApp.Api/AnkuApp.Api.csproj') -Raw
$settingsPath = Join-Path $env:APPDATA "Microsoft/UserSecrets/$($project.Project.PropertyGroup.UserSecretsId)/secrets.json"
$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$script:passed = 0
Add-Type -AssemblyName System.Net.Http
$script:http = New-Object System.Net.Http.HttpClient
$script:http.Timeout = [TimeSpan]::FromSeconds(40)

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
        $response = $script:http.SendAsync($request).GetAwaiter().GetResult()
        try {
            $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $code = [int]$response.StatusCode
            if ($code -ne $Expected) { throw "$Method $Path : beklenen HTTP $Expected, gelen $code. $content" }
            if ($content) { return ($content | ConvertFrom-Json) }
        } finally { $response.Dispose() }
    } finally { $request.Dispose() }
}
function FormToken([string]$Html) {
    $match = [regex]::Match($Html, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"')
    if (-not $match.Success) { throw 'MVC form guvenlik alani bulunamadi.' }
    return [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
}
function LoginPortal([string]$Email, [string]$Password) {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $page = Invoke-WebRequest "$PortalBaseUrl/Account/Login" -UseBasicParsing -WebSession $session
    Invoke-WebRequest "$PortalBaseUrl/Account/Login" -UseBasicParsing -WebSession $session -Method Post -Body @{
        Email = $Email; Password = $Password; __RequestVerificationToken = (FormToken $page.Content)
    } | Out-Null
    return $session
}

$admin = Api POST '/api/auth/login' -Payload @{ email = 'admin@ankuapp.test'; password = (Secret 'Seed:AdminPassword') }
$student = Api POST '/api/auth/login' -Payload @{ email = 'ogrenci@ankuapp.test'; password = (Secret 'Seed:StudentPassword') }
$manager = Api POST '/api/auth/login' -Payload @{ email = 'kulup@ankuapp.test'; password = (Secret 'Seed:ClubPassword') }
$announcementIds = @()
$menuIds = @()

try {
    foreach ($path in @('/api/announcements', '/api/meal-menus', '/api/meal-menus/today', '/api/content-sync')) {
        Api GET $path -Expected 401 | Out-Null
        Check $true "JWT gerekli: $path"
    }
    $tag = [Guid]::NewGuid().ToString('N')
    $payload = @{ title = "Week5 $tag"; summary = 'Temporary integration announcement'; sourceName = 'Ankara University'; sourceUrl = "https://oidb.ankara.edu.tr/?ankuapp-test=$tag"; publishedAt = [DateTimeOffset]::UtcNow.ToString('o') }
    foreach ($user in @($student, $manager)) {
        Api POST '/api/announcements' $user.accessToken $payload -Expected 403 | Out-Null
        Api POST '/api/announcements/refresh' $user.accessToken -Expected 403 | Out-Null
        Api POST '/api/meal-menus/refresh' $user.accessToken -Expected 403 | Out-Null
        Api GET '/api/content-sync' $user.accessToken -Expected 403 | Out-Null
        Check $true 'Ogrenci/kulup yetkilisi genel icerigi yonetemez veya yenileyemez'
    }
    $announcement = Api POST '/api/announcements' $admin.accessToken $payload -Expected 201
    $announcementIds += $announcement.id
    Check ($announcement.isManual -and $announcement.uniqueKey.Length -eq 64) 'Elle duyuru, kaynak ve UniqueKey olusur'
    $duplicate = $payload.Clone(); $duplicate.sourceUrl += '#details'
    Api POST '/api/announcements' $admin.accessToken $duplicate -Expected 409 | Out-Null
    Check $true 'Ayni kaynak fragment degisse bile tekrar eklenmez'
    $detail = Api GET "/api/announcements/$($announcement.id)" $student.accessToken
    Check ($detail.title -eq $payload.title) 'Ogrenci duyuru ayrintisini okuyabilir'
    foreach ($case in @(@{title=' '}, @{sourceUrl='javascript:alert(1)'}, @{sourceUrl='https://ankara.edu.tr.evil.test/a'}, @{publishedAt=$null})) {
        $bad = $payload.Clone(); foreach ($key in $case.Keys) { $bad[$key] = $case[$key] }
        Api POST '/api/announcements' $admin.accessToken $bad -Expected 400 | Out-Null
        Api PUT "/api/announcements/$($announcement.id)" $admin.accessToken $bad -Expected 400 | Out-Null
        Check $true 'Duyuru ekleme/guncelleme dogrulamasi'
    }
    $payload.title += ' Updated'
    Api PUT "/api/announcements/$($announcement.id)" $admin.accessToken $payload -Expected 204 | Out-Null
    $list = Api GET "/api/announcements?search=$tag&pageSize=1" $student.accessToken
    Check ($list.totalCount -eq 1 -and $list.items[0].title -eq $payload.title) 'Arama, sayfalama ve guncelleme ortak API verisini kullanir'
    Api GET '/api/announcements?page=2147483647&pageSize=100' $student.accessToken -Expected 400 | Out-Null
    Check $true 'Duyuru sayfalama tasmasi reddedilir'
    $testDate = [DateTime]::new(2099,1,1).AddDays((Get-Random -Minimum 0 -Maximum 300)).ToString('yyyy-MM-dd')
    $existing = Api GET "/api/meal-menus?from=$testDate&to=$testDate" $admin.accessToken
    if ($existing.items.Count -ne 0) { throw 'Gecici menu tarihi dolu; testi yeniden calistirin.' }
    $menuPayload = @{ menuDate=$testDate; dishes=@('Test Soup','Test Main','Test Side','Test Dessert'); totalCalories=1200; sourceName='Ankara University SKS'; sourceUrl='https://sks.ankara.edu.tr/yemek-hizmetleri-2/' }
    $menu = Api POST '/api/meal-menus' $admin.accessToken $menuPayload -Expected 201
    $menuIds += $menu.id
    Api POST '/api/meal-menus' $admin.accessToken $menuPayload -Expected 409 | Out-Null
    Check ($menu.dishes.Count -eq 4 -and $menu.isManual) 'Tarih, yemekler ve kaynak saklanir; ayni tarihe ikinci menu eklenmez'
    foreach ($user in @($student, $manager)) {
        Api POST '/api/meal-menus' $user.accessToken $menuPayload -Expected 403 | Out-Null
        Api PUT "/api/meal-menus/$($menu.id)" $user.accessToken $menuPayload -Expected 403 | Out-Null
        Api DELETE "/api/meal-menus/$($menu.id)" $user.accessToken -Expected 403 | Out-Null
        Api PUT "/api/announcements/$($announcement.id)" $user.accessToken $payload -Expected 403 | Out-Null
        Api DELETE "/api/announcements/$($announcement.id)" $user.accessToken -Expected 403 | Out-Null
        Check $true 'Icerik guncelleme ve silme yalniz yoneticiye acik'
    }
    foreach ($case in @(@{dishes=@(' ')}, @{totalCalories=-1}, @{menuDate=$null}, @{sourceUrl='file:///tmp/private'})) {
        $bad = $menuPayload.Clone(); foreach ($key in $case.Keys) { $bad[$key] = $case[$key] }
        Api POST '/api/meal-menus' $admin.accessToken $bad -Expected 400 | Out-Null
        Api PUT "/api/meal-menus/$($menu.id)" $admin.accessToken $bad -Expected 400 | Out-Null
        Check $true 'Menu ekleme/guncelleme dogrulamasi'
    }
    $menuPayload.dishes = @('Updated test dish')
    Api PUT "/api/meal-menus/$($menu.id)" $admin.accessToken $menuPayload -Expected 204 | Out-Null
    $readMenu = Api GET "/api/meal-menus?from=$testDate&to=$testDate" $student.accessToken
    Check ($readMenu.items[0].dishes[0] -eq 'Updated test dish') 'Ogrenci guncel menu verisini okur'
    $today = Api GET '/api/meal-menus/today' $student.accessToken
    Check ($today.date -match '^\d{4}-\d{2}-\d{2}$') 'Bugunun menusu Turkiye tarihiyle yanitlanir'
    $empty = Api GET '/api/meal-menus?from=2100-12-30&to=2100-12-30' $student.accessToken
    Check ($empty.items.Count -eq 0) 'Menu olmayan tarih acik bos liste doner'
    Api GET '/api/meal-menus?from=2026-11-05&to=2026-11-01' $student.accessToken -Expected 400 | Out-Null
    Api GET '/api/meal-menus?from=2026-01-01&to=2026-12-31' $student.accessToken -Expected 400 | Out-Null
    Check $true 'Gecersiz veya cok uzun tarih araligi reddedilir'

    $portal = LoginPortal 'admin@ankuapp.test' (Secret 'Seed:AdminPassword')
    foreach ($path in @('/Announcements', '/Announcements/Create', '/MealMenus', '/MealMenus/Create')) {
        $page = Invoke-WebRequest "$PortalBaseUrl$path" -UseBasicParsing -WebSession $portal
        Check ($page.StatusCode -eq 200 -and $page.Content.Contains('__RequestVerificationToken')) "Yonetici sayfasi ve CSRF formu: $path"
    }
    $form = Invoke-WebRequest "$PortalBaseUrl/Announcements/Create" -UseBasicParsing -WebSession $portal
    $portalTag = "Portal $tag"
    $portalUrl = "https://oidb.ankara.edu.tr/?ankuapp-portal-test=$tag"
    Invoke-WebRequest "$PortalBaseUrl/Announcements/Create" -UseBasicParsing -WebSession $portal -Method Post -Body @{
        __RequestVerificationToken=(FormToken $form.Content); Title=$portalTag; Summary='MVC integration';
        SourceName='Ankara University'; SourceUrl=$portalUrl; PublishedAt=[DateTime]::Now.ToString('yyyy-MM-ddTHH:mm')
    } | Out-Null
    $portalList = Api GET "/api/announcements?search=$tag" $admin.accessToken
    $createdInPortal = @($portalList.items | Where-Object { $_.sourceUrl -eq $portalUrl })
    $announcementIds += @($createdInPortal | ForEach-Object { $_.id })
    Check ($createdInPortal.Count -eq 1) 'MVC formuyla eklenen duyuru ogrenci API akisina gecer'
    $csrfStatus = 0
    try { $r = Invoke-WebRequest "$PortalBaseUrl/Announcements/Refresh" -UseBasicParsing -WebSession $portal -Method Post; $csrfStatus = [int]$r.StatusCode }
    catch { if ($_.Exception.Response) { $csrfStatus = [int]$_.Exception.Response.StatusCode } else { throw } }
    Check ($csrfStatus -eq 400) 'Portal yenileme islemi CSRF token olmadan reddedilir'
    $portalMenuDate = [DateTime]::Parse($testDate).AddDays(1).ToString('yyyy-MM-dd')
    $portalMenuForm = Invoke-WebRequest "$PortalBaseUrl/MealMenus/Create" -UseBasicParsing -WebSession $portal
    Invoke-WebRequest "$PortalBaseUrl/MealMenus/Create" -UseBasicParsing -WebSession $portal -Method Post -Body @{
        __RequestVerificationToken=(FormToken $portalMenuForm.Content); MenuDate=$portalMenuDate;
        DishesText="Portal Soup`nPortal Main"; TotalCalories='900'; SourceName='Ankara University SKS'; SourceUrl='https://sks.ankara.edu.tr/yemek-hizmetleri-2/'
    } | Out-Null
    $createdMenus = Api GET "/api/meal-menus?from=$portalMenuDate&to=$portalMenuDate" $admin.accessToken
    $createdInPortalMenu = @($createdMenus.items | Where-Object { $_.dishes[0] -eq 'Portal Soup' })
    $menuIds += @($createdInPortalMenu | ForEach-Object { $_.id })
    Check ($createdInPortalMenu.Count -eq 1 -and $createdInPortalMenu[0].dishes.Count -eq 2) 'MVC menu formu tarih ve yemek satirlarini API uzerinden kaydeder'
    $payload.title += ' <script>alert(1)</script>'
    Api PUT "/api/announcements/$($announcement.id)" $admin.accessToken $payload -Expected 204 | Out-Null
    $encodedPage = Invoke-WebRequest "$PortalBaseUrl/Announcements?search=$tag" -UseBasicParsing -WebSession $portal
    Check (-not $encodedPage.Content.Contains('<script>alert(1)</script>') -and $encodedPage.Content.Contains('&lt;script&gt;')) 'Duyuru metni portalda HTML olarak calistirilmaz'
    $managerPortal = LoginPortal 'kulup@ankuapp.test' (Secret 'Seed:ClubPassword')
    $denied = Invoke-WebRequest "$PortalBaseUrl/Announcements" -UseBasicParsing -WebSession $managerPortal
    Check ($denied.BaseResponse.ResponseUri.AbsolutePath -eq '/Account/AccessDenied') 'Kulup yetkilisi duyuru yonetim portalina giremez'

    if ($CheckSources) {
        $first = Api POST '/api/announcements/refresh' $admin.accessToken
        $second = Api POST '/api/announcements/refresh' $admin.accessToken
        Check ($first.imported -gt 0 -and $second.changed -eq 0) 'Resmi RSS okunur; yeniden yenileme duyuru cogaltmaz'
        $firstMenus = Api POST '/api/meal-menus/refresh' $admin.accessToken
        $monthStart = ([DateTime]::Parse($today.date)).ToString('yyyy-MM-01')
        $monthEnd = ([DateTime]::Parse($monthStart)).AddMonths(1).AddDays(-1).ToString('yyyy-MM-dd')
        $before = Api GET "/api/meal-menus?from=$monthStart&to=$monthEnd" $student.accessToken
        $secondMenus = Api POST '/api/meal-menus/refresh' $admin.accessToken
        $after = Api GET "/api/meal-menus?from=$monthStart&to=$monthEnd" $student.accessToken
        Check ($firstMenus.imported -gt 0 -and $secondMenus.imported -gt 0 -and $before.items.Count -eq $after.items.Count) 'Resmi aylik Excel menusu okunur ve tarihler cogalmaz'
        $protectedMenu = Api GET "/api/meal-menus/$($menu.id)" $student.accessToken
        Check ($protectedMenu.dishes[0] -eq 'Updated test dish') 'Elle girilen menu kaynak yenilemesinde korunur'
        $states = @(Api GET '/api/content-sync' $admin.accessToken)
        Check (@($states | Where-Object { $_.lastSuccessAt -and -not $_.lastError }).Count -eq 2) 'Kaynaklarin son basari durumu kaydedilir'
    }
    if ($FailureApiBaseUrl) {
        $beforeCount = (Api GET '/api/announcements' $admin.accessToken).totalCount
        $beforeStates = @(Api GET '/api/content-sync' $admin.accessToken)
        foreach ($kind in @('announcements', 'meal-menus')) {
            $failure = Api POST "/api/$kind/refresh" $admin.accessToken -Expected 503 -Base $FailureApiBaseUrl
            Check ([bool]$failure.message) "Bozuk kaynak HTTP 503 ve anlasilir hata doner: $kind"
        }
        $afterCount = (Api GET '/api/announcements' $admin.accessToken).totalCount
        $states = @(Api GET '/api/content-sync' $admin.accessToken)
        Check ($beforeCount -eq $afterCount -and @($states | Where-Object { $_.lastError }).Count -eq 2) 'Kaynak hatasi kayitlari silmez ve hata durumunu saklar'
        foreach ($state in $states) {
            $previous = $beforeStates | Where-Object { $_.id -eq $state.id }
            Check ($previous.lastSuccessAt -eq $state.lastSuccessAt) 'Kaynak hatasinda son basari tarihi korunur'
        }
        $readMenu = Api GET "/api/meal-menus/$($menu.id)" $student.accessToken
        Check ($readMenu.dishes[0] -eq 'Updated test dish') 'Kaynak bozukken onbellekteki menu okunabilir'
        # Kaynak saglik durumunu gercek kaynakla yeniden duzelt.
        if ($CheckSources) {
            Api POST '/api/announcements/refresh' $admin.accessToken | Out-Null
            Api POST '/api/meal-menus/refresh' $admin.accessToken | Out-Null
        }
    }
}
finally {
    foreach ($id in $announcementIds) { Api DELETE "/api/announcements/$id" $admin.accessToken -Expected 204 | Out-Null }
    foreach ($id in $menuIds) { Api DELETE "/api/meal-menus/$id" $admin.accessToken -Expected 204 | Out-Null }
    $script:http.Dispose()
    Write-Host '[OK] Gecici duyurular ve menuler temizlendi'
}
Write-Host "Tamamlandi: $script:passed entegrasyon kontrolu basarili."
