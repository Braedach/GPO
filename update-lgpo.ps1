function Get-WindowsEdition {
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
    $destinationPath = "C:\ProgramData\GPO"
    $lgpoZipUrl = "https://github.com/Braedach/GPO/raw/development/LGPO.zip"
    $lgpoZip = "$destinationPath\LGPO.zip"
    $urlgpo  = "https://raw.githubusercontent.com/Braedach/GPO/development/registry.pol"

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
        Write-Host "Failed to download LGPO.zip. Error: $($_.Exception.Message)" -ForegroundColor Red
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

        gpresult /H "$destinationPath\report.html"
        gpresult /r > "$destinationPath\gpresult.txt"
        Write-Host "Saved GPO Reports to $destinationPath" -ForegroundColor Green
    } catch {
        Write-Host "Implementation of registry.pol failed - Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Restart-Windows {
    $msg = "A major change has occurred by the Network Administrator. The system will restart in 120 seconds. Please save your work."
    msg * $msg
    shutdown.exe /r /t 120 /c "Group policy update completed. Restarting system."
}

# === Script Execution Flow ===
Get-WindowsEdition
Set-RestorePoint
Get-LGPO
Restart-Windows
