# Run from Windows PowerShell 5.1, in the interactive account that runs Flow.
[CmdletBinding()]
param([switch]$Start)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $env:LOCALAPPDATA 'FlowRemoteBridge'
New-Item -ItemType Directory -Force $destination | Out-Null
Get-Process FlowRemoteBridge -ErrorAction SilentlyContinue | Stop-Process
$binary = Join-Path $destination 'FlowRemoteBridge.exe'
Remove-Item $binary -ErrorAction SilentlyContinue
$source = Get-Content (Join-Path $root 'clients\windows\FlowRemoteBridge.cs') -Raw
Add-Type -TypeDefinition $source -ReferencedAssemblies System.Core,System.Web.Extensions -OutputAssembly $binary -OutputType WindowsApplication
$config = Join-Path $destination 'config.json'
if (!(Test-Path $config)) {
    Copy-Item (Join-Path $root 'clients\windows\config.example.json') $config
}
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute $binary
$login = New-ScheduledTaskTrigger -AtLogOn -User $identity
$retry = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'Flow Remote Bridge' -Action $action -Trigger @($login,$retry) -Settings $settings -Principal $principal -Force | Out-Null
if ($Start) {
    Start-ScheduledTask -TaskName 'Flow Remote Bridge'
} else {
    Disable-ScheduledTask -TaskName 'Flow Remote Bridge' | Out-Null
    Write-Output "Installed, task disabled. Edit $config and verify SSH first."
    Write-Output "Then: Enable-ScheduledTask 'Flow Remote Bridge'; Start-ScheduledTask 'Flow Remote Bridge'"
}
