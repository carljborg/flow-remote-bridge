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
