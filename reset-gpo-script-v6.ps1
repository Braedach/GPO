<#
    Updated 2025-07-07

    Purpose:
    Reset the LGPO and Security Policy via Live Response.
    Must be run as Administrator. Designed for modular testing.
    DO NOT RUN Reset-Secedit yet — it's a placeholder for future testing.
#>

function Get-WindowsEdition {
    $edition = (Get-WmiObject -Class Win32_OperatingSystem).OperatingSystemSKU
    $homeEditions = @(1, 2, 3, 4, 5, 98, 99)

    if ($homeEditions -contains $edition) {
        throw "Unsupported Windows edition detected: Home Edition. Exiting script..."
    } else {
        Write-Host "Windows edition is valid for this operation." -ForegroundColor Green
    }
}

function Set-Restore-Point {
    try {
        # The following command sets the system restore point creation frequency to 5 minutes - required to reduce interval for testing purposes.
        Invoke-Command { reg.exe ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 5 /f }
        Write-Host "System restore point interval updated to 5 minutes"
        Checkpoint-Computer -Description "Pre Group Policy Restoration" -RestorePointType "MODIFY_SETTINGS"
        Write-Host "System restore point created successfully."
    } catch {
        Write-Host "Failed to create system restore point: $($_.Exception.Message)"
    }
}

function Reset-GPO {
    # Set paths to the appropriate locations
     param (
        [string]$RootPathGroupPolicy = "$env:SystemRoot\System32\GroupPolicy",
        [string]$RootPathGroupPolicyUsers = "$env:SystemRoot\System32\GroupPolicyUsers",
        [string]$RootPathSecurityDatabase = "$env:SystemRoot\System32\security\database",
        [string]$BasePath = "$env:ProgramData\GPO",
        [string]$BasePathOld = "$env:ProgramFiles\GPO",
        [string]$DestinationPath = "$env:ProgramData\GPO"
    )
   # Verify LGPO.exe exists
    $ExePath = "$DestinationPath\LGPO.exe"
    if (-not (Test-Path -Path $ExePath -PathType Leaf)) {
        Write-Host "LGPO.exe not found at: $ExePath" -ForegroundColor Red
        Write-Host "Please ensure LGPO.exe is present in the specified path." -Foreground Red
        exit
    } else {
        try {
            # Reset the group policy and security database
            Write-Host "Resetting Group Policy and Security Database..." -ForegroundColor Green
           & $lgpoExe /reset
        }
        catch {
            Write-Host "Failed to reset Group Policy and Security Database: $($_.Exception.Message)" -ForegroundColor Red
            exit
        }
    }

    # Remove all the old GPO paths and files and purge the system
    try {
         $pathsToDelete = @(
        @{ Path = $BasePathOld; Description = "ProgramFiles GPO" }
    )

    foreach ($item in $pathsToDelete) {
        $path = $item.Path
        $desc = $item.Description

        if (Test-Path $path) {
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "Deleted: $desc ($path)" -ForegroundColor Green
            } catch {
                Write-Host "Error deleting $desc ($path): $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Not found: $desc ($path)" -ForegroundColor Red
        }
    }
    }
    catch {
        Write-Host "Failed to delete old GPO paths: $($_.Exception.Message)" -ForegroundColor Red
    }
}


function Restart-Windows {
    Restart-Computer -Force
}

# --- Script Execution ---

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "This script must be run as Administrator."
} else {
    Get-WindowsEdition
    Set-Restore-Point
    Reset-GPO
    # Restart-Windows
}
