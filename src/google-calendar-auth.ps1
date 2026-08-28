param(
    [Parameter(Mandatory = $true)][string]$ClientId,
    [Parameter(Mandatory = $true)][string]$ClientSecret,
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)][string]$AuthUri,
    [Parameter(Mandatory = $true)][string]$TokenUri,
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [string]$SourceCredentialFile = ''
)

$ErrorActionPreference = 'Stop'
$port = Get-Random -Minimum 49152 -Maximum 65535
$redirectUri = "http://127.0.0.1:$port/"
$state = [Guid]::NewGuid().ToString('N')
$listener = New-Object System.Net.HttpListener
$tokenResponseText = ''

try {
    $listener.Prefixes.Add($redirectUri)
    $listener.Start()
    $scope = 'https://www.googleapis.com/auth/calendar.readonly'
    $authUrl = $AuthUri + '?client_id=' + [Uri]::EscapeDataString($ClientId) + '&redirect_uri=' + [Uri]::EscapeDataString($redirectUri) + '&response_type=code&scope=' + [Uri]::EscapeDataString($scope) + '&access_type=offline&prompt=consent&state=' + $state
    [System.IO.File]::WriteAllText("$ResultPath.url", $authUrl, [Text.UTF8Encoding]::new($false))
    & "$env:WINDIR\System32\rundll32.exe" 'url.dll,FileProtocolHandler' $authUrl
    Remove-Item -LiteralPath "$ResultPath.url" -Force -ErrorAction SilentlyContinue
    $context = $listener.GetContext()
    $query = $context.Request.QueryString
    $responseText = '<html><body>Google Calendar authorization received. You may close this window.</body></html>'
    $bytes = [Text.Encoding]::UTF8.GetBytes($responseText)
    $context.Response.ContentType = 'text/html; charset=utf-8'
    $context.Response.ContentLength64 = $bytes.Length
    $context.Response.KeepAlive = $false
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.Close()
    if ([string]$query['state'] -ne $state) { throw 'OAuth state validation failed.' }
    $code = [string]$query['code']
    if ([string]::IsNullOrWhiteSpace($code)) { throw ([string]$query['error']) }

    $values = New-Object System.Collections.Specialized.NameValueCollection
    $values.Add('code', $code)
    $values.Add('client_id', $ClientId)
    $values.Add('client_secret', $ClientSecret)
    $values.Add('redirect_uri', $redirectUri)
    $values.Add('grant_type', 'authorization_code')
    $web = New-Object System.Net.WebClient
    $tokenBytes = $web.UploadValues($TokenUri, 'POST', $values)
    $tokenResponseText = [Text.Encoding]::UTF8.GetString($tokenBytes)
    $tokens = $tokenResponseText | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$tokens.access_token)) { throw 'Google did not return an access token.' }

    $result = [ordered]@{
        success = $true
        clientId = $ClientId
        clientSecret = $ClientSecret
        projectId = $ProjectId
        authUri = $AuthUri
        tokenUri = $TokenUri
        redirectUri = $redirectUri
        accessToken = [string]$tokens.access_token
        refreshToken = [string]$tokens.refresh_token
        tokenResponse = $tokenResponseText
        sourceCredentialFile = $SourceCredentialFile
        configured = $true
    }
}
catch {
    $result = [ordered]@{ success = $false; error = $_.Exception.Message; tokenResponse = $tokenResponseText }
}
finally {
    $listener.Stop()
    $listener.Close()
    [System.IO.File]::WriteAllText($ResultPath, ($result | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
}
