<#
.SYNOPSIS
    Provisions VirtualBox VM shells for SentinelOps adhering strictly to hardware sizing constraints.
.DESCRIPTION
    Creates:
    - VM 1: SentinelOps-SOC-Server (6 GB RAM, 3 vCPUs, 45 GB dynamic VDI, Dual NICs: Host-Only + Internal Net)
    - VM 2: SentinelOps-Victim (2 GB RAM, 1 vCPU, 15 GB dynamic VDI, Single NIC: Internal Net)
    Preserves 8.0 GB to 10.0 GB of RAM for Windows 11 host.
#>

[CmdletBinding()]
param(
    [string]$VBoxPath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [string]$VMStorageDir = "$HOME\VirtualBox VMs"
)

$ErrorActionPreference = "Stop"

Write-Host "=== SentinelOps: Virtual Machine Provisioning ===" -ForegroundColor Cyan

if (-not (Test-Path $VBoxPath)) {
    $vboxCmd = Get-Command "VBoxManage.exe" -ErrorAction SilentlyContinue
    if ($vboxCmd) { $VBoxPath = $vboxCmd.Source } else { throw "VBoxManage.exe not found." }
}

# VM 1: SOC Server Parameters (6 GB RAM, 3 vCPU, 45 GB Dynamic Disk)
$VM1_Name = "SentinelOps-SOC-Server"
$VM1_Folder = Join-Path $VMStorageDir $VM1_Name
$VM1_Disk = Join-Path $VM1_Folder "$VM1_Name.vdi"

# VM 2: Victim Parameters (2 GB RAM, 1 vCPU, 15 GB Dynamic Disk)
$VM2_Name = "SentinelOps-Victim"
$VM2_Folder = Join-Path $VMStorageDir $VM2_Name
$VM2_Disk = Join-Path $VM2_Folder "$VM2_Name.vdi"

Write-Host "`n[1/2] Checking VM 1: $VM1_Name..." -ForegroundColor Yellow
$existingVMs = & "$VBoxPath" list vms
if ($existingVMs -match $VM1_Name) {
    Write-Host "VM 1 ($VM1_Name) already exists. Skipping creation." -ForegroundColor Green
} else {
    Write-Host "Creating $VM1_Name (Ubuntu 64-bit)..."
    & "$VBoxPath" createvm --name $VM1_Name --ostype "Ubuntu_64" --register
    # Tuned to 6144 MB (6 GB) to preserve 8-10 GB host memory
    & "$VBoxPath" modifyvm $VM1_Name --memory 6144 --cpus 3 --vram 16 --boot1 dvd --boot2 disk --boot3 none --boot4 none
    & "$VBoxPath" modifyvm $VM1_Name --nic1 hostonly --hostonlyadapter1 "VirtualBox Host-Only Ethernet Adapter"
    & "$VBoxPath" modifyvm $VM1_Name --nic2 intnet --intnet2 "SentinelOps-LabNet"
    & "$VBoxPath" storagectl $VM1_Name --name "SATA Controller" --add sata --controller IntelAhci
    
    if (-not (Test-Path $VM1_Folder)) { New-Item -ItemType Directory -Path $VM1_Folder -Force | Out-Null }
    Write-Host "Creating 45 GB dynamic VDI for $VM1_Name..."
    & "$VBoxPath" createmedium disk --filename $VM1_Disk --size 46080 --format VDI --variant Standard
    & "$VBoxPath" storageattach $VM1_Name --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $VM1_Disk
    Write-Host "VM 1 ($VM1_Name) shell configured successfully." -ForegroundColor Green
}

Write-Host "`n[2/2] Checking VM 2: $VM2_Name..." -ForegroundColor Yellow
if ($existingVMs -match $VM2_Name) {
    Write-Host "VM 2 ($VM2_Name) already exists. Skipping creation." -ForegroundColor Green
} else {
    Write-Host "Creating $VM2_Name (Ubuntu 64-bit)..."
    & "$VBoxPath" createvm --name $VM2_Name --ostype "Ubuntu_64" --register
    & "$VBoxPath" modifyvm $VM2_Name --memory 2048 --cpus 1 --vram 16 --boot1 dvd --boot2 disk --boot3 none --boot4 none
    & "$VBoxPath" modifyvm $VM2_Name --nic1 intnet --intnet1 "SentinelOps-LabNet"
    & "$VBoxPath" storagectl $VM2_Name --name "SATA Controller" --add sata --controller IntelAhci
    
    if (-not (Test-Path $VM2_Folder)) { New-Item -ItemType Directory -Path $VM2_Folder -Force | Out-Null }
    Write-Host "Creating 15 GB dynamic VDI for $VM2_Name..."
    & "$VBoxPath" createmedium disk --filename $VM2_Disk --size 15360 --format VDI --variant Standard
    & "$VBoxPath" storageattach $VM2_Name --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $VM2_Disk
    Write-Host "VM 2 ($VM2_Name) shell configured successfully." -ForegroundColor Green
}

Write-Host "`n=== VM Provisioning Complete ===" -ForegroundColor Green
Write-Host "Host RAM Preserved: 8.0 GB - 10.0 GB"
Write-Host "To attach Ubuntu 24.04 Server ISO and start installation:"
Write-Host "VBoxManage storageattach <VM_Name> --storagectl 'SATA Controller' --port 1 --device 0 --type dvddrive --medium <path_to_iso>"
