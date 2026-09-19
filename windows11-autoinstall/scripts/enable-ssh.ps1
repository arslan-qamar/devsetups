$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Install Microsoft's native OpenSSH server.
$capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'

if ($capability.State -ne 'Installed') {
    Add-WindowsCapability `
        -Online `
        -Name 'OpenSSH.Server~~~~0.0.1.0' |
        Out-Null
}

# Use PowerShell as the shell for SSH commands.
$openSshRegistry = 'HKLM:\SOFTWARE\OpenSSH'

New-Item `
    -Path $openSshRegistry `
    -Force |
    Out-Null

New-ItemProperty `
    -Path $openSshRegistry `
    -Name 'DefaultShell' `
    -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -PropertyType String `
    -Force |
    Out-Null

Set-Service sshd -StartupType Automatic

# Ensure SSH is allowed regardless of the network profile Windows assigns.
Remove-NetFirewallRule `
    -Name 'OpenSSH-Server-In-TCP' `
    -ErrorAction SilentlyContinue

New-NetFirewallRule `
    -Name 'OpenSSH-Server-In-TCP' `
    -DisplayName 'OpenSSH Server (sshd)' `
    -Enabled True `
    -Profile Any `
    -Direction Inbound `
    -Protocol TCP `
    -Action Allow `
    -LocalPort 22 |
    Out-Null

Start-Service sshd

# Sysprep can tear down the remote session while it runs.
# Launch final box preparation independently as SYSTEM.
$prepareScript = 'C:\Windows\Temp\prepare-vagrant-box.ps1'
$completeOobeScript = 'C:\Windows\Temp\complete-oobe.ps1'
$sysprepAnswerFile = 'C:\Windows\Temp\SysprepUnattend.xml'

Copy-Item `
    -LiteralPath (Join-Path $PSScriptRoot 'prepare-vagrant-box.ps1') `
    -Destination $prepareScript `
    -Force

Copy-Item `
    -LiteralPath (Join-Path $PSScriptRoot 'complete-oobe.ps1') `
    -Destination $completeOobeScript `
    -Force

Copy-Item `
    -LiteralPath (Join-Path $PSScriptRoot 'SysprepUnattend.xml') `
    -Destination $sysprepAnswerFile `
    -Force

$sysprepAction = New-ScheduledTaskAction `
    -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$prepareScript`""

$sysprepPrincipal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName 'PrepareVagrantBox' `
    -Action $sysprepAction `
    -Principal $sysprepPrincipal `
    -Force |
    Out-Null

# Autologon was only needed for the initial bootstrap.
Remove-ItemProperty `
    -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' `
    -Name AutoAdminLogon `
    -ErrorAction SilentlyContinue
