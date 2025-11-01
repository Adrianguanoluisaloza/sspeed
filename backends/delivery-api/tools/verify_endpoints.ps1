param(
  [string]$BaseUrl = "http://localhost:7070",
  [string]$AdminEmail = "admin@demo.com",
  [string]$AdminPassword = "admin",
  [int]$ClienteId = 123,
  [int]$RepartidorId = 123,
  [int]$PedidoId = 0,
  [int]$NegocioId = 0,
  [string]$OutFile = $(Join-Path (Get-Location) ("verify_results_" + (Get-Date -Format yyyyMMdd_HHmmss) + ".json"))
)

$ProgressPreference = 'SilentlyContinue'

function Write-Section($title) {
  Write-Host "`n=== $title ===" -ForegroundColor Cyan
}

function Invoke-Json {
  param(
    [Parameter(Mandatory=$true)][ValidateSet('GET','POST','PUT','DELETE')] [string]$Method,
    [Parameter(Mandatory=$true)][string]$Path,
    [object]$Body = $null,
    [string]$Token = $null
  )
  $uri = ("{0}{1}" -f $BaseUrl, $Path)
  $headers = @{ 'Content-Type'='application/json; charset=UTF-8'; 'ngrok-skip-browser-warning'='true' }
  if ($Token -and $Token.Length -gt 0) { $headers['Authorization'] = "Bearer $Token" }
  try {
    if ($Body -ne $null) {
      $json = ($Body | ConvertTo-Json -Depth 6 -Compress)
    } else { $json = $null }

    $resp = Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -TimeoutSec 30 -Body $json -ErrorAction Stop
    # Wrap common fields
    return [pscustomobject]@{
      ok = $true
      status = 200
      data = $resp
      errorMessage = $null
      path = $Path
      method = $Method
    }
  } catch {
    $err = $_
    $status = if ($err.Exception.Response) { $err.Exception.Response.StatusCode.Value__ } else { -1 }
    $body = $null
    try { $reader = New-Object System.IO.StreamReader($err.Exception.Response.GetResponseStream()); $body = $reader.ReadToEnd(); $reader.Close() } catch {}
    return [pscustomobject]@{
      ok = $false
      status = $status
      data = $body
      errorMessage = $err.Exception.Message
      path = $Path
      method = $Method
    }
  }
}

$results = @()
$token = $null

Write-Section "Smoke: GET /categorias"
$r1 = Invoke-Json -Method GET -Path "/categorias"
$results += $r1
if ($r1.ok) { Write-Host "OK" -ForegroundColor Green } else { Write-Warning "Fail [$($r1.status)] $($r1.errorMessage)" }

Write-Section "Login: POST /auth/login"
$rLogin = Invoke-Json -Method POST -Path "/auth/login" -Body @{ correo = $AdminEmail; contrasena = $AdminPassword }
$results += $rLogin
if ($rLogin.ok -and $rLogin.data) {
  # Extraer token si existe
  try {
    if ($rLogin.data.data -and $rLogin.data.data.token) { $token = $rLogin.data.data.token }
    elseif ($rLogin.data.token) { $token = $rLogin.data.token }
  } catch {}
  $tokenText = if ($token) { 'si' } else { 'no' }
  Write-Host ("OK (token: {0})" -f $tokenText) -ForegroundColor Green
} else {
  Write-Warning "Login falló; se continuará sin token (si endpoints no lo exigen)."
}

Write-Section "Chat: iniciar conversación"
$r2 = Invoke-Json -Method POST -Path "/chat/iniciar" -Body @{ idCliente = $ClienteId }
$results += $r2
$convId = $null
if ($r2.ok -and $r2.data) {
  try {
    $convId = $r2.data.data.id_conversacion
    if (-not $convId) { $convId = $r2.data.id_conversacion }
  } catch {}
}
$convText = if ($convId) { $convId } else { 'null' }
Write-Host ("id_conversacion: {0}" -f $convText)

if ($convId) {
  Write-Section "Chat: enviar mensaje"
  $r3 = Invoke-Json -Method POST -Path "/chat/mensajes" -Body @{ idConversacion = [int64]$convId; idRemitente = $ClienteId; mensaje = "Hola soporte" } -Token $token
  $results += $r3

  Write-Section "Chat: listar mensajes"
  $r4 = Invoke-Json -Method GET -Path ("/chat/conversaciones/{0}/mensajes" -f $convId) -Token $token
  $results += $r4
}

Write-Section "ChatBot: mensaje 'hola'"
$r5 = Invoke-Json -Method POST -Path "/chat/bot/mensajes" -Body @{ idRemitente = $ClienteId; mensaje = "hola" } -Token $token
$results += $r5

Write-Section "Soporte: iniciar"
$r6 = Invoke-Json -Method POST -Path "/soporte/iniciar" -Body @{ idUsuario = $ClienteId; rol = "cliente" } -Token $token
$results += $r6
$convSoporte = $null
if ($r6.ok -and $r6.data) { try { $convSoporte = $r6.data.data.id_conversacion; if (-not $convSoporte) { $convSoporte = $r6.data.id_conversacion } } catch {} }

if ($convSoporte) {
  Write-Section "Soporte: enviar mensaje"
  $r7 = Invoke-Json -Method POST -Path "/soporte/mensajes" -Body @{ idConversacion = [int64]$convSoporte; idRemitente = $ClienteId; mensaje = "Necesito ayuda" } -Token $token
  $results += $r7
}

Write-Section "Tracking: subir coordenadas repartidor"
$r8 = Invoke-Json -Method PUT -Path ("/ubicaciones/repartidor/{0}" -f $RepartidorId) -Body @{ latitud = 0.123; longitud = -79.1 } -Token $token
$results += $r8

if ($PedidoId -gt 0) {
  Write-Section "Tracking: ubicacion de pedido"
  $r9 = Invoke-Json -Method GET -Path ("/tracking/pedido/{0}" -f $PedidoId) -Token $token
  $results += $r9

  Write-Section "Tracking: ruta de pedido"
  $r10 = Invoke-Json -Method GET -Path ("/tracking/pedido/{0}/ruta" -f $PedidoId) -Token $token
  $results += $r10
} else {
  Write-Host "Saltado GET /tracking por PedidoId = 0" -ForegroundColor Yellow
}

if ($NegocioId -gt 0) {
  Write-Section "Negocio: stats"
  $r11 = Invoke-Json -Method GET -Path ("/negocios/{0}/stats" -f $NegocioId) -Token $token
  $results += $r11
}

# Resumen y guardado
Write-Section "Resumen"
$summary = $results | ForEach-Object {
  [pscustomobject]@{
    method = $_.method
    path = $_.path
    ok = $_.ok
    status = $_.status
  }
}
$summary | Format-Table -AutoSize | Out-String | Write-Host

# Guardar JSON con resultados completos
$results | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutFile -Encoding UTF8
Write-Host "Resultados guardados en: $OutFile" -ForegroundColor Green
