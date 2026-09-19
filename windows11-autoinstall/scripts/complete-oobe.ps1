$ErrorActionPreference = 'Stop'

# OpenSSH is deliberately kept stopped while specialize and OOBE run. Starting
# it here makes the Vagrant communicator a reliable signal that first-run setup
# has completed.
Set-Service sshd -StartupType Automatic

# AutoLogon is used once so FirstLogonCommands can publish the readiness signal.
# Remove its credential values immediately after the first desktop is reached.
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

foreach ($name in 'AutoAdminLogon', 'DefaultPassword', 'DefaultUserName', 'DefaultDomainName') {
    Remove-ItemProperty `
        -Path $winlogon `
        -Name $name `
        -ErrorAction SilentlyContinue
}

Start-Service sshd
