function Get-WindowsEdition {
    <#
    .SYNOPSIS
        Checks the Windows Edition is compliant
        Tested 2025-10-01

    .DESCRIPTION
        This function checks the Windows edition to ensure it is not a Home edition.
    #>

    $edition = (Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU
    $homeEditions = @(1, 2, 3, 4, 5, 98, 99)

    if ($homeEditions -contains $edition) {
        Write-Host "Unsupported Windows edition detected: Home Edition. Exiting script..." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "Windows edition is valid for this operation." -ForegroundColor Green
    }
}

function Set-RestorePoint {
    <#
    .SYNOPSIS
        Creates a system restore point before applying group policies.
        Tested 2025-10-04
    .DESCRIPTION
        This function sets the system restore point creation frequency and creates a restore point.
    #>

    try {
        reg.exe ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 5 /f
        Write-Host "System restore point interval updated to 5 minutes"
        Checkpoint-Computer -Description "Pre Group Policy Application" -RestorePointType "MODIFY_SETTINGS"
        Write-Host "System restore point created successfully."
    } catch {
        Write-Host "Failed to create system restore point: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Get-LGPO {
    <#
    .SYNOPSIS
        Downloads and applies Local Group Policy Objects (LGPO) from a specified source.
        Tested 2025-10-04
    .DESCRIPTION
        This function performs the following tasks:
        1. Ensures the target GPO directory exists and is clean.
        2. Downloads LGPO.exe and registry.pol from a specified GitHub repository.
        3. Applies the registry.pol settings using LGPO.exe.
        4. Forces a Group Policy update.
        5. Generates Group Policy result reports in HTML and text formats.

        The function exits on download or execution failure to ensure integrity.
    #>

    # This code is not right and will not work until the files are uploaded to the repo or release assets.
    # Please upload LGPO.zip and registry.pol to the repository or release assets for this script to function correctly.
    # ENSURE THAT YOU SEPERATE THE PRODUCTION FROM DEVELOPMENT - THIS SHOULD NOW WORK
    
    $destinationPath = "$env:ProgramData\GPO"
    $lgpoZipUrl = "https://github.com/Braedach/GPO/releases/download/production/LGPO.zip"
    $lgpoZip = "$destinationPath\LGPO.zip"
    $urlgpo  = "https://github.com/Braedach/GPO/releases/download/production/registry.pol"
    

    # Ensure directory exists and clean it
    if (-not (Test-Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        Write-Host "Directory created: $destinationPath" -ForegroundColor Green
    } else {
        Get-ChildItem -Path $destinationPath -File | Remove-Item -Force
        Write-Host "Cleaned existing files in $destinationPath" -ForegroundColor Green
    }

    # Download LGPO.zip
    try {
    Invoke-WebRequest -Uri $lgpoZipUrl -OutFile $lgpoZip -ErrorAction Stop
    Write-Host "Successfully downloaded LGPO.zip" -ForegroundColor Green
    } catch {
    Write-Host "LGPO.zip not found at $lgpoZipUrl. Please ensure it is uploaded to the repo or release assets." -ForegroundColor Red
    exit 1
    }   


    # Extract LGPO.exe
    try {
        Expand-Archive -Path $lgpoZip -DestinationPath $destinationPath -Force
        $lgpoExe = Get-ChildItem -Path $destinationPath -Recurse -Filter "LGPO.exe" | Select-Object -First 1
        if ($null -eq $lgpoExe) {
            Write-Host "LGPO.exe not found in archive." -ForegroundColor Red
            exit 1
        }
        Write-Host "LGPO.exe extracted to $($lgpoExe.FullName)" -ForegroundColor Green
    } catch {
        Write-Host "Failed to extract LGPO.exe. Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    # Download registry.pol
    try {
        $destinationPol = "$destinationPath\registry.pol"
        Invoke-WebRequest -Uri $urlgpo -OutFile $destinationPol -ErrorAction Stop
        Write-Host "Successfully downloaded registry.pol" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download registry.pol. Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    # Apply registry.pol with LGPO.exe
    try {
        & $lgpoExe.FullName /m "$destinationPath\registry.pol" /v > "$destinationPath\lgpo-verbose.txt" 2> "$destinationPath\lgpo-error.txt"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "LGPO.exe failed with exit code $LASTEXITCODE" -ForegroundColor Red
            exit $LASTEXITCODE
        }

        gpupdate /force
        Write-Host "LGPO settings applied. Group Policy update completed." -ForegroundColor Green
        
        # Modify permissions to allow all users to read the reports
        $whoami = whoami
        gpresult /r /user $whoami > "$destinationPath\gpresult.txt"
        gpresult /H /user $whoami > "$destinationPath\report.html"
        icacls "$destinationPath\*" /grant "Users:(R)" /T
        icalcs "$destinationPath\*" /grant "Authenticated Users:(R)" /T
        icalcs "$destinationPath\*" /grant "Everyone:(R)" /T

        Write-Host "Saved GPO Reports to $destinationPath" -ForegroundColor Green
    } catch {
        Write-Host "Implementation of registry.pol failed - Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Restart-Windows {
    <#
    .SYNOPSIS
        Schedules a system restart to apply group policy changes.
        Tested 2025-10-04
    .DESCRIPTION
        This function schedules a system restart in 2 minutes with a notification.
    #>
    shutdown.exe /r /t 180 /c "Group policy update completed. Restarting system in 3 minutes."
}

# === Script Execution Flow ===
Get-WindowsEdition
Set-RestorePoint
Get-LGPO
Restart-Windows
