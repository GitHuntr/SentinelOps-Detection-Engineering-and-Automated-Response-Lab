<#
.SYNOPSIS
    Configures Oracle VirtualBox Network Adapters for SentinelOps.
.DESCRIPTION
    1. Creates/Configures the Host-Only network 'SentinelOps-MgmtNet' (192.168.56.0/24).
    2. Verifies VBoxManage availability on Windows 11 host.
#>

[CmdletBinding()]
param(
    [string]$VBoxPath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
)

$ErrorActionPreference = "Stop"

Write-Host "=== SentinelOps: VirtualBox Network Initialization ===" -ForegroundColor Cyan

# 1. Check VBoxManage
if (-not (Test-Path $VBoxPath)) {
    Write-Warning "VBoxManage.exe not found at default path: $VBoxPath"
    $vboxCmd = Get-Command "VBoxManage.exe" -ErrorAction SilentlyContinue
    if ($vboxCmd) {
        $VBoxPath = $vboxCmd.Source
        Write-Host "Found VBoxManage in PATH: $VBoxPath" -ForegroundColor Green
    } else {
        throw "Oracle VirtualBox is required. Please verify installation path."
    }
}

# 2. Inspect Host-Only Interfaces
Write-Host "Querying VirtualBox Host-Only interfaces..." -ForegroundColor Yellow
$hostOnlyList = & "$VBoxPath" list hostonlyifs

if ($hostOnlyList -match "VirtualBox Host-Only Ethernet Adapter") {
    Write-Host "Host-Only interface already available." -ForegroundColor Green
} else {
    Write-Host "Creating new Host-Only network adapter..." -ForegroundColor Yellow
    & "$VBoxPath" hostonlyif create
}

# 3. Configure IP addressing on Host-Only Network
Write-Host "Setting Host-Only IP to 192.168.56.1 / 255.255.255.0..." -ForegroundColor Yellow
& "$VBoxPath" hostonlyif ipconfig "VirtualBox Host-Only Ethernet Adapter" --ip 192.168.56.1 --netmask 255.255.255.0

Write-Host "Disabling DHCP on Host-Only Network (Static IPs used for lab)..." -ForegroundColor Yellow
& "$VBoxPath" dhcpserver remove --netname "HostInterfaceNetworking-VirtualBox Host-Only Ethernet Adapter" 2>$null
if ($LASTEXITCODE -ne 0) {
    # DHCP server might not exist, which is fine
    $global:LASTEXITCODE = 0
}

Write-Host "=== Network Setup Completed Successfully ===" -ForegroundColor Green
Write-Host "Management Network: 192.168.56.0/24 (Host Gateway: 192.168.56.1)"
Write-Host "Internal Lab Network: SentinelOps-LabNet (Configured directly on VM adapters)"

