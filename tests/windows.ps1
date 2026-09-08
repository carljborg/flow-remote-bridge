# Compilation and pure connection-policy tests. No live Flow data, network or UI input.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'build'
New-Item -ItemType Directory -Force $build | Out-Null
$exe = Join-Path $build 'FlowRemoteBridge.exe'
Remove-Item $exe -ErrorAction SilentlyContinue
Add-Type -TypeDefinition (Get-Content (Join-Path $root 'clients\windows\FlowRemoteBridge.cs') -Raw) -ReferencedAssemblies System.Core,System.Web.Extensions -OutputAssembly $exe -OutputType WindowsApplication
$assembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($exe))
$type = $assembly.GetType('FlowRemoteBridge')
$method = $type.GetMethod('ConnectedLog', [Reflection.BindingFlags]'NonPublic,Static')
$cases = @(
    @{Text=''; Expected=$false},
    @{Text="Client Status received: 0`nordinary line"; Expected=$true},
    @{Text="Client Status received: 0`nClient Status received: 20"; Expected=$false},
    @{Text="Client Status received: 0`n===== Parsec: started"; Expected=$false},
    @{Text="===== Parsec: started`nClient Status received: 0"; Expected=$true},
    @{Text='Client Status received: 01'; Expected=$false}
)
foreach ($case in $cases) {
    $actual = $method.Invoke($null, @($case.Text))
    if ($actual -ne $case.Expected) {throw 'Connection policy assertion failed'}
}
Write-Output 'Windows compilation and 6 connection-policy cases passed.'
# Verify the Windows serializer preserves a long multilingual dictation, without
# opening Flow's database or submitting input to a desktop.
$json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$body = (('Long dictation ' + [char]0x00E6 + [char]0x4E16 + [char]0x754C + "`n") * 2000) + 'final words '
$wire = [Text.Encoding]::UTF8.GetBytes($json.Serialize(@{op='paste'; text=$body}))
$decoded = $json.DeserializeObject([Text.Encoding]::UTF8.GetString($wire))
if ($decoded.text -cne $body) {throw 'Long dictation JSON roundtrip failed'}
if ([Text.Encoding]::UTF8.GetByteCount($body) -gt 65536) {throw 'Fixture exceeds receiver text limit'}
Write-Output 'Long multilingual Windows payload roundtrip passed.'

$pendingMethod = $type.GetMethod('PendingAction', [Reflection.BindingFlags]'NonPublic,Static')
foreach ($case in @(
    @{Age=1.0; Foreground=$false; Expected='pause'},
    @{Age=90.0; Foreground=$false; Expected='pause'},
    @{Age=91.0; Foreground=$true; Expected='ready'},
    @{Age=1500.0; Foreground=$true; Expected='ready'},
    @{Age=1501.0; Foreground=$false; Expected='expire'},
    @{Age=1501.0; Foreground=$true; Expected='expire'}
)) {
    if ($pendingMethod.Invoke($null, @($case.Age, $case.Foreground)) -ne $case.Expected) {
        throw 'Pending pause/return/expiry assertion failed'
    }
}
Write-Output 'Windows pending pause/return/expiry cases passed.'
