param(
    [string]$ApiBaseUrl = 'http://localhost:5080',
    [string]$PortalBaseUrl = 'http://localhost:5025'
)

# API ve MVC ayakta olmali. Parolalar yalnizca yerel user-secrets'ten okunur.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
[xml]$project = Get-Content -LiteralPath (Join-Path $repoRoot 'backend/AnkuApp.Api/AnkuApp.Api.csproj') -Raw
$secretId = [string]$project.Project.PropertyGroup.UserSecretsId
$secretPath = Join-Path $env:APPDATA "Microsoft/UserSecrets/$secretId/secrets.json"
if (-not (Test-Path -LiteralPath $secretPath)) { throw 'API user-secrets ayarlari bulunamadi.' }
$secrets = Get-Content -LiteralPath $secretPath -Raw | ConvertFrom-Json
$script:passed = 0

function Read-Secret([string]$Key) {
    $value = $secrets.$Key
    if (-not $value) {
        $value = $secrets
        foreach ($part in $Key.Split(':')) { $value = $value.$part }
    }
    if (-not $value) { throw "Eksik yerel ayar: $Key. Ayarlayip API'yi Development ortaminda yeniden baslatin." }
    return [string]$value
}

function Assert-Check([bool]$Condition, [string]$Label) {
    if (-not $Condition) { throw "KONTROL BASARISIZ: $Label" }
    $script:passed++
    Write-Host "[OK] $Label"
}

function Api([string]$Method, [string]$Path, [string]$Token = '', $Payload = $null, [int]$Expected = 200) {
    $request = @{ Uri = $ApiBaseUrl.TrimEnd('/') + $Path; Method = $Method; UseBasicParsing = $true; TimeoutSec = 15 }
    if ($Token) { $request.Headers = @{ Authorization = "Bearer $Token" } }
    if ($null -ne $Payload) {
        $request.ContentType = 'application/json; charset=utf-8'
        $request.Body = [Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Depth 8))
    }
    $content = ''
    try { $response = Invoke-WebRequest @request; $code = [int]$response.StatusCode; $content = $response.Content }
    catch {
        if ($null -eq $_.Exception.Response) { throw "API'ye ulasilamadi: $ApiBaseUrl" }
        $code = [int]$_.Exception.Response.StatusCode
        $content = $_.ErrorDetails.Message
    }
    if ($code -ne $Expected) { throw "$Method $Path : beklenen HTTP $Expected, gelen $code" }
    if ($content) { return ($content | ConvertFrom-Json) }
}

function Form-Token([string]$Html) {
    $match = [regex]::Match($Html, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"')
    if (-not $match.Success) { throw 'MVC form guvenlik alani bulunamadi.' }
    return [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
}

function Portal-Login([string]$Email, [string]$Password) {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $page = Invoke-WebRequest "$PortalBaseUrl/Account/Login" -UseBasicParsing -WebSession $session
    $result = Invoke-WebRequest "$PortalBaseUrl/Account/Login" -UseBasicParsing -WebSession $session -Method Post -Body @{
        Email = $Email; Password = $Password; __RequestVerificationToken = (Form-Token $page.Content)
    }
    return @{ Session = $session; Page = $result }
}

$admin = Api POST '/api/auth/login' -Payload @{ email = 'admin@ankuapp.test'; password = (Read-Secret 'Seed:AdminPassword') }
$manager = Api POST '/api/auth/login' -Payload @{ email = 'kulup@ankuapp.test'; password = (Read-Secret 'Seed:ClubPassword') }
$studentPassword = Read-Secret 'Seed:StudentPassword'
$student = Api POST '/api/auth/login' -Payload @{ email = 'ogrenci@ankuapp.test'; password = $studentPassword }
Assert-Check ($student.user.email -eq 'ogrenci@ankuapp.test') 'Ogrenci girisi'
$clubId = $null

try {
    $tag = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $club = Api POST '/api/clubs' $admin.accessToken @{
        name = "Week4 Club $tag"; description = 'Gecici entegrasyon kaydi'; authorizedUserEmail = 'kulup@ankuapp.test'
    } -Expected 201
    $clubId = [int]$club.id
    $date = [DateTimeOffset]::UtcNow.AddDays(2)
    $draft = Api POST '/api/events' $admin.accessToken @{
        clubId = $clubId; title = "Week4 Draft $tag"; eventDate = $date.ToString('o'); capacity = 30; status = 'Draft'
    } -Expected 201
    $studentList = Api GET "/api/events?clubId=$clubId" $student.accessToken
    Assert-Check ($studentList.totalCount -eq 0) 'Taslaklar ogrenci listesine ve toplam sayiya girmez'
    Api GET "/api/events/$($draft.id)" $student.accessToken -Expected 404 | Out-Null
    Assert-Check $true 'Ogrenci taslak ayrintisini acamaz'
    Api GET "/api/events/$($draft.id)" $admin.accessToken | Out-Null
    Assert-Check $true 'Yonetici taslagi gorebilir'
    Api POST '/api/events' $student.accessToken @{ clubId = $clubId; title = 'Forbidden'; eventDate = $date.ToString('o'); capacity = 1 } -Expected 403 | Out-Null
    Assert-Check $true 'Ogrenci etkinlik yonetimi yapamaz'

    $portal = Portal-Login 'admin@ankuapp.test' (Read-Secret 'Seed:AdminPassword')
    $create = Invoke-WebRequest "$PortalBaseUrl/Events/Create?clubId=$clubId" -UseBasicParsing -WebSession $portal.Session
    try { $turkey = [TimeZoneInfo]::FindSystemTimeZoneById('Turkey Standard Time') }
    catch { $turkey = [TimeZoneInfo]::FindSystemTimeZoneById('Europe/Istanbul') }
    $localDate = [TimeZoneInfo]::ConvertTimeFromUtc($date.UtcDateTime, $turkey).ToString('yyyy-MM-ddTHH:mm')
    $title = "Week4 Shared Event $tag"
    Invoke-WebRequest "$PortalBaseUrl/Events/Create" -UseBasicParsing -WebSession $portal.Session -Method Post -Body @{
        __RequestVerificationToken = (Form-Token $create.Content)
        ClubId = $clubId; Title = $title; Description = 'MVC -> API -> Flutter'; EventDate = $localDate; Capacity = 40; Status = 'Published'
    } | Out-Null
    $feed = Api GET "/api/events?clubId=$clubId&status=Published" $student.accessToken
    Assert-Check ($feed.totalCount -eq 1 -and $feed.items[0].title -eq $title) 'MVC kaydi ogrencinin mobil API akisinda gorunur'
    $shared = $feed.items[0]
    Assert-Check ([Math]::Abs(([DateTimeOffset]::Parse($shared.eventDate) - $date).TotalSeconds) -lt 61) 'MVC Turkiye saati UTC olarak ayni ani saklar'
    $clubDetail = Api GET "/api/clubs/$clubId" $student.accessToken
    Assert-Check ($clubDetail.name -eq $club.name -and -not $clubDetail.authorizedUserEmail) 'Kulup ayrintisi ve yetkili e-postasinin gizlenmesi'

    $updatedTitle = "$title Updated"
    Api PUT "/api/events/$($shared.id)" $admin.accessToken @{
        clubId = $clubId; title = $updatedTitle; eventDate = $date.ToString('o'); capacity = 50; status = 'Published'
    } -Expected 204 | Out-Null
    $portalPage = Invoke-WebRequest "$PortalBaseUrl/Events?clubId=$clubId" -UseBasicParsing -WebSession $portal.Session
    Assert-Check ($portalPage.Content.Contains($updatedTitle)) 'Mobil/API guncellemesi MVC listesinde gorunur'
    Api PUT "/api/events/$($shared.id)" $manager.accessToken @{
        clubId = $clubId; title = $updatedTitle; eventDate = $date.ToString('o'); capacity = 50; status = 'Cancelled'
    } -Expected 204 | Out-Null
    $feed = Api GET "/api/events?clubId=$clubId&status=Published" $student.accessToken
    $detail = Api GET "/api/events/$($shared.id)" $student.accessToken
    Assert-Check ($feed.totalCount -eq 0 -and $detail.status -eq 'Cancelled') 'Iptal edilen etkinlik akistan cikar, ayrintida iptal bilgisi kalir'
    $studentPortal = Portal-Login 'ogrenci@ankuapp.test' $studentPassword
    Assert-Check (-not $studentPortal.Session.Cookies.GetCookies([uri]$PortalBaseUrl)['AnkuApp.Portal']) 'Ogrenci MVC yonetim portalina giremez'
    Api GET '/api/events?status=invalid' $student.accessToken -Expected 400 | Out-Null
    Assert-Check $true 'Gecersiz durum filtresi reddedilir'
}
finally {
    if ($null -ne $clubId) {
        $temporary = Api GET "/api/events?clubId=$clubId&pageSize=100" $admin.accessToken
        foreach ($event in $temporary.items) { Api DELETE "/api/events/$($event.id)" $admin.accessToken -Expected 204 | Out-Null }
        Api DELETE "/api/clubs/$clubId" $admin.accessToken -Expected 204 | Out-Null
        Write-Host '[OK] Gecici kulup ve etkinlikler temizlendi'
    }
}
Write-Host "Tamamlandi: $script:passed entegrasyon kontrolu basarili."
