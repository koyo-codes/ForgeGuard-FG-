# ============================================================
#  ForgeNeo TempGuard v7 - Auto install
# ============================================================

# --- Settings -----------------------------------------------
$TempStop      = 90
$TempResume    = 60
$CheckInterval = 2
# ------------------------------------------------------------

$paused = $false

# Auto-detect LibreHardwareMonitorLib.dll
function Find-LhmDll {
    $candidates = @(
        # winget install path (all users)
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
        "$env:ProgramFiles\LibreHardwareMonitor",
        "$env:ProgramFiles(x86)\LibreHardwareMonitor"
    )
    foreach ($base in $candidates) {
        if (Test-Path $base) {
            $found = Get-ChildItem -Path $base -Filter "LibreHardwareMonitorLib.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    return $null
}

$DllPath = Find-LhmDll
if ($null -eq $DllPath) {
    Write-Host "[INFO] LibreHardwareMonitor not found. Installing automatically..." -ForegroundColor Yellow
    try {
        $winget = Get-Command winget -ErrorAction Stop
        & winget install LibreHardwareMonitor --accept-source-agreements --accept-package-agreements
        # Search again after install
        $DllPath = Find-LhmDll
        if ($null -eq $DllPath) {
            Write-Host "[NG] Installation succeeded but DLL still not found. Please restart the script." -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK] Installation complete." -ForegroundColor Green
    }
    catch {
        Write-Host "[NG] winget not found. Please install LibreHardwareMonitor manually:" -ForegroundColor Red
        Write-Host "     https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases" -ForegroundColor Yellow
        exit 1
    }
}
Write-Host "[OK] DLL found: $DllPath" -ForegroundColor Green

# Load suspend/resume functions
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ProcessSuspender {
    [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr handle);
    [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr handle);
}
"@

# Load LibreHardwareMonitor DLL
try {
    Add-Type -Path $DllPath
    $computer = New-Object LibreHardwareMonitor.Hardware.Computer
    $computer.IsGpuEnabled = $true
    $computer.Open()
    Write-Host "[OK] LibreHardwareMonitor loaded" -ForegroundColor Green
}
catch {
    Write-Host "[NG] Failed to load DLL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

function Get-GpuHotspotTemp {
    try {
        foreach ($hw in $computer.Hardware) {
            if ($hw.HardwareType -match "Gpu") {
                $hw.Update()
                foreach ($sensor in $hw.Sensors) {
                    if ($sensor.SensorType -eq [LibreHardwareMonitor.Hardware.SensorType]::Temperature) {
                        if ($sensor.Name -match "Hotspot|Junction|Hot Spot") {
                            return [math]::Round($sensor.Value, 1)
                        }
                    }
                }
                foreach ($sensor in $hw.Sensors) {
                    if ($sensor.SensorType -eq [LibreHardwareMonitor.Hardware.SensorType]::Temperature) {
                        return [math]::Round($sensor.Value, 1)
                    }
                }
            }
        }
        return $null
    }
    catch { return $null }
}

function Get-ForgeProcess {
    $procs = Get-Process python* -ErrorAction SilentlyContinue | Sort-Object WorkingSet -Descending
    if ($procs) { return $procs[0] }
    return $null
}

function Suspend-ForgeProcess {
    $proc = Get-ForgeProcess
    if ($null -eq $proc) {
        Write-Host "  [NG] Forge Neo process not found" -ForegroundColor Red
        return $false
    }
    [ProcessSuspender]::NtSuspendProcess($proc.Handle) | Out-Null
    Write-Host "  [OK] Process suspended (PID: $($proc.Id))" -ForegroundColor Green
    return $true
}

function Resume-ForgeProcess {
    $proc = Get-ForgeProcess
    if ($null -eq $proc) {
        Write-Host "  [NG] Forge Neo process not found" -ForegroundColor Red
        return $false
    }
    [ProcessSuspender]::NtResumeProcess($proc.Handle) | Out-Null
    Write-Host "  [OK] Process resumed (PID: $($proc.Id))" -ForegroundColor Green
    return $true
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  ForgeNeo TempGuard v5" -ForegroundColor Cyan
Write-Host "  STOP  : ${TempStop} C or above" -ForegroundColor Cyan
Write-Host "  RESUME: ${TempResume} C or below" -ForegroundColor Cyan
Write-Host "  Check interval: ${CheckInterval} sec" -ForegroundColor Cyan
Write-Host "  Press Ctrl+C to quit" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Verify Forge Neo is running
$forge = Get-ForgeProcess
if ($null -eq $forge) {
    Write-Host "[WARN] Forge Neo (python) process not found. Please start Forge Neo first." -ForegroundColor Yellow
} else {
    Write-Host "[OK] Forge Neo found: PID $($forge.Id)" -ForegroundColor Green
}

while ($true) {
    $temp = Get-GpuHotspotTemp
    $now  = Get-Date -Format "HH:mm:ss"

    if ($null -eq $temp) {
        Write-Host "[$now] WARN: Cannot get GPU temp" -ForegroundColor Yellow
    }
    elseif ($temp -ge $TempStop -and -not $paused) {
        Write-Host "[$now] HOT: ${temp}C (>=${TempStop}C) -> Suspending Forge Neo..." -ForegroundColor Red
        $ok = Suspend-ForgeProcess
        if ($ok) {
            $paused = $true
            Write-Host "  [PAUSED] Waiting for temp to drop below ${TempResume}C..." -ForegroundColor Yellow
        }
    }
    elseif ($temp -le $TempResume -and $paused) {
        Write-Host "[$now] COOL: ${temp}C (<=${TempResume}C) -> Resuming Forge Neo..." -ForegroundColor Green
        $ok = Resume-ForgeProcess
        if ($ok) { $paused = $false }
    }
    else {
        $status = if ($paused) { "[PAUSED]" } else { "[RUNNING]" }
        Write-Host "[$now] $status  GPU: ${temp}C" -ForegroundColor Gray
    }

    Start-Sleep -Seconds $CheckInterval
}