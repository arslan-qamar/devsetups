$ErrorActionPreference = 'Stop'

$drive = $env:VM_SHARED_DRIVE
if ([string]::IsNullOrWhiteSpace($env:VM_SHARED_HOST)) {
    $env:VM_SHARED_HOST = ($env:SSH_CONNECTION -split '\s+')[0]
}
$remotePath = "\\$($env:VM_SHARED_HOST)\$($env:VM_SHARED_NAME)"

if ([string]::IsNullOrWhiteSpace($drive) -or
    [string]::IsNullOrWhiteSpace($env:VM_SHARED_HOST) -or
    [string]::IsNullOrWhiteSpace($env:VM_SHARED_NAME) -or
    [string]::IsNullOrWhiteSpace($env:VM_SHARED_USER) -or
    [string]::IsNullOrWhiteSpace($env:VM_SHARED_PASSWORD)) {
    throw 'The shared-folder drive, host, share, user, and password are required.'
}

$client = [System.Net.Sockets.TcpClient]::new()
try {
    $connection = $client.BeginConnect($env:VM_SHARED_HOST, 445, $null, $null)
    if (-not $connection.AsyncWaitHandle.WaitOne(3000)) {
        Write-Warning 'Optional SMB share is unreachable on TCP 445; continuing provisioning.'
        exit 0
    }
    $client.EndConnect($connection)
}
catch {
    Write-Warning 'Optional SMB share is unreachable on TCP 445; continuing provisioning.'
    exit 0
}
finally {
    $client.Dispose()
}

$existing = Get-SmbMapping -LocalPath $drive -ErrorAction SilentlyContinue
if ($null -ne $existing -and
    $existing.RemotePath -eq $remotePath -and
    $existing.Status -eq 'OK') {
    Write-Host "Shared folder is already mapped at $drive"
    exit 0
}

if ($null -ne $existing) {
    Remove-SmbMapping -LocalPath $drive -Force -UpdateProfile
}

$mappingOutput = & net.exe use `
    $drive `
    $remotePath `
    $env:VM_SHARED_PASSWORD `
    "/user:$($env:VM_SHARED_USER)" `
    /persistent:yes 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not map the optional SMB share (net use exit $LASTEXITCODE); continuing provisioning."
    exit 0
}

Write-Host "Mapped the shared host folder to $drive"
