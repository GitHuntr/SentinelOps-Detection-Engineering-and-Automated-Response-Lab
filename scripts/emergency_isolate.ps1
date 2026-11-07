<#
.SYNOPSIS
    Emergency Kill Switch / Host-level Isolation Script for SentinelOps.
.DESCRIPTION
    Instantly stops the victim VM or disconnects virtual network interfaces
    if runaway attack simulation or malicious lateral movement occurs.
#>

[CmdletBinding()]
param(
    [string]$VBoxPath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [string]$VictimVMName = "SentinelOps-Victim",
    [ValidateSet("poweroff", "disconnect_net")]
    [string]$Action = "poweroff"
)

$ErrorActionPreference = "Stop"

Write-Warning "=== SENTINELOPS EMERGENCY ISOLATION TRIGGERED ==="

if (-not (Test-Path $VBoxPath)) {
    $vboxCmd = Get-Command "VBoxManage.exe" -ErrorAction SilentlyContinue
    if ($vboxCmd) { $VBoxPath = $vboxCmd.Source } else { throw "VBoxManage.exe not found." }
}

if ($Action -eq "poweroff") {
    Write-Host "Forcefully powering off victim virtual machine: $VictimVMName..." -ForegroundColor Red
    & "$VBoxPath" controlvm $VictimVMName poweroff
    Write-Host "Victim VM is POWERED OFF." -ForegroundColor Green
} elseif ($Action -eq "disconnect_net") {
    Write-Host "Severing network cable connection on $VictimVMName (NIC 1)..." -ForegroundColor Yellow
    & "$VBoxPath" controlvm $VictimVMName setlinkstate1 off
    Write-Host "Virtual network cable unplugged. Host isolated." -ForegroundColor Green
}

