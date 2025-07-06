<#
    Updated 2025-07-07

    Purpose:
    Allow for the updating of the LGPO via Live Response.
    Script must be run as Administrator for local testing — PowerShell permissions may require modification.
    Adjusted to ensure only Machine policies are applied via LGPO.

    NOTE: The secedit SECURITYPOLICY update section is not yet implemented.
    It's under testing due to recently identified issues.

    This script is modularized for ease of testing and isolation.
#>

function Get-WindowsEdition {
    <#
    .SYNOPSIS
        Validates that the current Windows edition is supported.

    .DESCRIPTION
        Checks whether the local OS SKU corresponds to a Windows Home Edition.
        If detected, the script exits to prevent unsupported GPO operations.

    .OUTPUTS
        None. Exits the script if an unsupported edition is found.
    #>
    $edition = (Get-WmiObject -Class Win32_OperatingSystem).OperatingSystemSKU
    $homeEditions = @(1, 2, 3, 4, 5, 98, 99)

    if ($homeEditions -contains $edition) {
        Write-Host "Unsupported Windows edition detected: Home Edition. Exiting script..." -ForegroundColor Red
        exit
    } else {
        Write-Host "Windows edition is valid for this operation." -ForegroundColor Green
    }
}

function Set-Restore-Point {
    try {
        # The following command sets the system restore point creation frequency to 5 minutes - required to reduce interval for testing purposes.
        Invoke-Command { reg.exe ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 5 /f }
        Write-Host "System restore point interval updated to 5 minutes"
        Checkpoint-Computer -Description "Pre Group Policy Application" -RestorePointType "MODIFY_SETTINGS"
        Write-Host "System restore point created successfully."
    } catch {
        Write-Host "Failed to create system restore point: $($_.Exception.Message)"
    }
}


function Export-LGPO {
    <#
    .SYNOPSIS
        Exports the system’s local group policy and security settings into a fixed backup directory.

    .DESCRIPTION
        Uses secedit and LGPO.exe to extract security and GPO settings.
        All output is stored in the target directory
    #>

    $basePath = "$env:ProgramData\GPO"
    $backupPath = "$env:ProgramData\GPO\Backup"

    # Ensure backup directory exists
    if (-not (Test-Path $backupPath)) {
        try {
            New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
            Write-Host "Created backup directory: $backupPath" -ForegroundColor Green
        }
        catch {
            throw "Failed to create backup directory '$backupPath'. Error: $($_.Exception.Message)"
        }
    }

    try {
        Write-Host "Exporting security settings using secedit..." -ForegroundColor Cyan
        secedit /export /cfg "$backupPath\secpol-backup.inf" /areas SECURITYPOLICY /log "$backupPath\secedit-export.log" /quiet
        Write-Host "Security policy exported to $backupPath\secpol-backup.inf" -ForegroundColor Green

        Write-Host "Generating rollback SDB database..." -ForegroundColor Cyan
        secedit /generaterollback /cfg "$backupPath\secpol-backup.inf" /db "$backupPath\secpol-backup.sdb" /log "$backupPath\secedit-rollback.log" /quiet
        Write-Host "Rollback SDB file created at $backupPath\secpol-backup.sdb" -ForegroundColor Green

        $lgpoExe = "$basePath\LGPO.exe"
        if (-not (Test-Path $lgpoExe)) {
            # Notice that the LGPO.exe is not found
            throw "LGPO.exe not found at $lgpoExe - please ensure it is downloaded and placed in the correct directory."
        }
        else {
            # Export Local Group Policy using LGPO.exe
            Write-Host "LGPO.exe found at $lgpoExe" -ForegroundColor Green
            Write-Host "Backing up Local Group Policy using LGPO.exe..." -ForegroundColor Cyan
            & $lgpoExe /b "`"$backupPath`""
            Write-Host "Local Group Policy exported to $backupPath" -ForegroundColor Green
        }
        Write-Host "Export completed successfully. All files are located in $backupPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Export failed: $($_.Exception.Message)" -ForegroundColor Red
    }


}



function Get-LGPO {
    <#
    .SYNOPSIS
        Downloads and applies local group policies using LGPO.exe.

    .DESCRIPTION
        Ensures required directories exist, downloads LGPO tools
        and registry.pol, applies the GPO via LGPO.exe, and generates result reports.

    .OUTPUTS
        None. Generates logs and GPO result files in the target directory.
    #>

    $basePath = "$env:ProgramData\GPO"
    $lgpoExePath = "$basePath\LGPO.exe"
    $registryPolPath = "$basePath\registry.pol"

    $files = @{
        "LGPO.exe"     = "https://raw.githubusercontent.com/Braedach/GPO/main/LGPO.exe"
        "registry.pol" = "https://raw.githubusercontent.com/Braedach/GPO/main/registry.pol"
        "secpol-policy.inf"  = "https://raw.githubusercontent.com/Braedach/GPO/main/secpol-policy.inf"
    }

    # Ensure base directory exists
    if (-not (Test-Path $basePath)) {
        try {
            New-Item -ItemType Directory -Path $basePath -Force | Out-Null
            Write-Host "Created base directory: $basePath" -ForegroundColor Green
        } catch {
            throw "Failed to create base directory '$basePath'. Error: $($_.Exception.Message)"
        }
    } else {
        # Clean up old files in base path
        Get-ChildItem -Path $basePath -File | Remove-Item -Force
        Write-Host "Cleared existing files in $basePath" -ForegroundColor Yellow
    }

    # Download required files
    try {
        foreach ($file in $files.Keys) {
            $url = $files[$file]
            $destination = Join-Path $basePath $file

            Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
            Write-Host "Downloaded $file to $destination" -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to download $file. Error: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }

    # Apply LGPO and secedit settings
    try {
        Write-Host "Applying LGPO settings..." -ForegroundColor Cyan
        & $lgpoExePath /m $registryPolPath /v > "$basePath\lgpo-verbose.txt" 2> "$basePath\lgpo-error.txt"

        gpupdate /force
        Write-Host "Group Policy update completed." -ForegroundColor Green

        gpresult /H "$basePath\report.html"
        gpresult /r > "$basePath\gpresult.txt"
        Write-Host "Saved GPO reports to $basePath" -ForegroundColor Green

        Write-Host "LGPO settings applied successfully." -ForegroundColor Green

        Write-Host "Applying security policy from secedit..." -ForegroundColor Cyan
        # According to Microsoft you must validate a policy before you try to apply it so the quiet flag is not a good idea and needs escape code
        secedit /validate /cfg "$basePath\secpol-policy.inf" /log "$basePath\secedit-validate.log" 
        # This line below is wrong - it should validate against the current database
        secedit /configure /db "$basePath\secpol-backup.sdb" /cfg "$basePath\secpol-policy.inf" /areas SECURITYPOLICY /log "$basePath\secedit-configure.log" /quiet
        Write-Host "Security policy applied successfully." -ForegroundColor Green 

    } catch {
        Write-Host "Failed to apply LGPO and secedit policy settings. Error: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
}




function Restart-Windows {
    <#
    .SYNOPSIS
        Forces a system reboot.

    .DESCRIPTION
        Reboots the computer with no prompt or delay.
        Useful after applying GPO or security settings that require a restart.

    .OUTPUTS
        None. System will restart.
    #>
    Restart-Computer -Force
}

f




# --- Script Execution ---

    # Ensure script is run as Administrator
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "This script must be run as Administrator."
    }
    else {
        Get-WindowsEdition
        Set-Restore-Point
        Export-LGPO
        Get-LGPO
        Restart-Windows
    }
