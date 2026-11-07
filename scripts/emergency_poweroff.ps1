<#
.SYNOPSIS
    Emergency Kill Switch / Power-off Script for SentinelOps (Last-Resort Fail-safe).
.DESCRIPTION
    Forcibly halts the victim VM in Oracle VirtualBox if runaway adversary activity
    or severe lab containment failure occurs.
.WARNING
    POTENTIALLY DESTRUCTIVE: This simulates pulling the physical power cord.
    It may corrupt uncommitted disk state or cause in-memory forensic data loss.
    Use only when out-of-band management fails or immediate shutdown is essential.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$VBoxPath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [string]$VictimVMName = "SentinelOps-Victim",
    [ValidateSet("poweroff", "disconnect_net")]
    [string]$Action = "poweroff"
)

$ErrorActionPreference = "Stop"

Write-Warning "=== SENTINELOPS: EMERGENCY FAIL-SAFE TRIGGERED ==="

if (-not (Test-Path $VBoxPath)) {
    $vboxCmd = Get-Command "VBoxManage.exe" -ErrorAction SilentlyContinue
    if ($vboxCmd) { $VBoxPath = $vboxCmd.Source } else { throw "VBoxManage.exe not found at $VBoxPath" }
}

if ($Action -eq "poweroff") {
    Write-Warning "Action: POTENTIALLY DESTRUCTIVE UNGRACEFUL POWER-OFF"
    Write-Host "Sending ACPI/forced poweroff signal to $VictimVMName..." -ForegroundColor Red
    & "$VBoxPath" controlvm $VictimVMName poweroff
    Write-Host "Victim VM is POWERED OFF." -ForegroundColor Green
} elseif ($Action -eq "disconnect_net") {
    Write-Host "Disconnecting virtual network cable on $VictimVMName (NIC 1)..." -ForegroundColor Yellow
    & "$VBoxPath" controlvm $VictimVMName setlinkstate1 off
    Write-Host "Virtual network interface disconnected. Endpoint isolated from lab network." -ForegroundColor Green
}

