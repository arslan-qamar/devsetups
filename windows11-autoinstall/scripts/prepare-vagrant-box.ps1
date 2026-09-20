$ErrorActionPreference = 'Stop'
$log = 'C:\Windows\Temp\prepare-vagrant-box.log'
$sysprepAnswerFile = 'C:\Windows\Temp\SysprepUnattend.xml'
$virtioGuestTools = 'C:\Windows\Temp\virtio-win-guest-tools.exe'

if (-not (Test-Path -LiteralPath $sysprepAnswerFile)) {
    throw "Missing Sysprep answer file: $sysprepAnswerFile"
}

if (-not (Test-Path -LiteralPath $virtioGuestTools)) {
    throw "Missing virtio-win Guest Tools installer: $virtioGuestTools"
}

Start-Transcript -Path $log -Force | Out-Null

try {
    # Install the Windows 11 virtio GPU driver and SPICE agent as Local System
    # so driver installation remains unattended.
    Write-Host 'Installing virtio-win Guest Tools...'
    $virtioInstall = Start-Process `
        -FilePath $virtioGuestTools `
        -ArgumentList '/install', '/quiet', '/norestart' `
        -Wait `
        -PassThru

    if ($virtioInstall.ExitCode -notin 0, 3010) {
        throw "virtio-win Guest Tools installer failed with exit code $($virtioInstall.ExitCode)."
    }

    Write-Host "virtio-win Guest Tools installed with exit code $($virtioInstall.ExitCode)."

    # Windows 11 24H2 can automatically start device encryption on TPM and
    # Secure Boot capable systems. A generalized Vagrant box must not retain a
    # volume encrypted against the build VM's TPM state.
    $bitLockerNamespace = 'root/CIMV2/Security/MicrosoftVolumeEncryption'
    $volume = Get-CimInstance `
        -Namespace $bitLockerNamespace `
        -ClassName Win32_EncryptableVolume `
        -Filter "DriveLetter = 'C:'"

    if ($null -eq $volume) {
        throw 'Could not find the C: volume through the BitLocker WMI provider.'
    }

    $conversion = Invoke-CimMethod `
        -InputObject $volume `
        -MethodName GetConversionStatus `
        -Arguments @{ PrecisionFactor = [uint32]0 }

    if ($conversion.ConversionStatus -ne 0) {
        Write-Host "C: is $($conversion.EncryptionPercentage)% encrypted; starting decryption."
        $manageBdeOutput = & manage-bde.exe -off C: 2>&1
        $manageBdeExitCode = $LASTEXITCODE
        $manageBdeOutput | ForEach-Object { Write-Host $_ }

        if ($manageBdeExitCode -ne 0) {
            throw "manage-bde.exe -off C: failed with exit code $manageBdeExitCode."
        }

        $decryptionDeadline = (Get-Date).AddHours(2)
        do {
            Start-Sleep -Seconds 10
            $conversion = Invoke-CimMethod `
                -InputObject $volume `
                -MethodName GetConversionStatus `
                -Arguments @{ PrecisionFactor = [uint32]0 }
            Write-Host "C: encryption remaining: $($conversion.EncryptionPercentage)% (state $($conversion.ConversionStatus))."

            if ((Get-Date) -ge $decryptionDeadline) {
                throw 'Timed out after two hours while waiting for C: to decrypt.'
            }
        } while ($conversion.ConversionStatus -ne 0)
    }

    Write-Host 'C: is fully decrypted and safe to generalize.'

    # This ISO registered Copilot for the build user without provisioning it for
    # every user. Sysprep rejects that mismatch with 0x80073cf2.
    Get-AppxPackage -AllUsers -Name 'Microsoft.Copilot' | ForEach-Object {
        Remove-AppxPackage `
            -Package $_.PackageFullName `
            -AllUsers `
            -ErrorAction Stop
    }

    Get-AppxProvisionedPackage -Online |
        Where-Object DisplayName -eq 'Microsoft.Copilot' |
        ForEach-Object {
            Remove-AppxProvisionedPackage `
                -Online `
                -PackageName $_.PackageName `
                -ErrorAction Stop |
                Out-Null
        }
}
finally {
    Stop-Transcript | Out-Null
}

# Prevent Vagrant from treating an SSH service started during specialize as a
# completed first boot. The Sysprep FirstLogonCommand starts it after OOBE.
Set-Service sshd -StartupType Manual
Stop-Service sshd -Force

& 'C:\Windows\System32\Sysprep\Sysprep.exe' `
    /generalize `
    /oobe `
    /shutdown `
    /quiet `
    "/unattend:$sysprepAnswerFile"

exit $LASTEXITCODE
