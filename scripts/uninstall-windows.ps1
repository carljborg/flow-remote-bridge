$ErrorActionPreference = 'Stop'
$task = Get-ScheduledTask -TaskName 'Flow Remote Bridge' -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName 'Flow Remote Bridge'
    Unregister-ScheduledTask -TaskName 'Flow Remote Bridge' -Confirm:$false
}
Get-Process FlowRemoteBridge -ErrorAction SilentlyContinue | Stop-Process
Remove-Item (Join-Path $env:LOCALAPPDATA 'FlowRemoteBridge\FlowRemoteBridge.exe') -ErrorAction SilentlyContinue
Write-Output 'Removed task and executable. Configuration and logs retained in %LOCALAPPDATA%\FlowRemoteBridge.'
