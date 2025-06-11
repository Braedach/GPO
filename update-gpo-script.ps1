<#
    Updated 2025-06-11

    Purpose:
    
    Allow for the updating of the LGPO via Live response
    Script must be run as Administrator for testing if run locally - changes may be required in PowerShell permissions
    Retested the script found multiple errors - have corrected
    Updated error checking - modified commands

    Code is set to update the LGPO

#>

function Get-LGPO {
    # Variables
    $destinationPath = "C:\Program Files\GPO"
    $oldPath = "C:\Program Files\Sysinternals"
    $urltool = "https://raw.githubusercontent.com/Braedach/GPO/main/LGPO.exe"
    $urlgpo = "https://raw.githubusercontent.com/Braedach/GPO/main/registry.pol"

    # Cleanup - remove old files if they exist
    if (Test-Path "$oldPath\LGPO.exe") {
        Remove-Item "$oldPath\LGPO.exe" -Force
        Write-Host "Removed old LGPO.exe from $oldPath" -ForegroundColor Yellow
    }
    
    if (Test-Path "$oldPath\registry.pol") {
        Remove-Item "$oldPath\registry.pol" -Force
        Write-Host "Removed old registry.pol from $oldPath" -ForegroundColor Yellow
    }

    # Create new destination folder if it doesn't exist
    if (!(Test-Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force
    }

    try {
        # Download LGPO tool
        Invoke-WebRequest -Uri $urltool -OutFile "$destinationPath\LGPO.exe" -ErrorAction Stop
        Write-Host "Successfully downloaded LGPO.exe" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download LGPO.exe. Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    try {
        # Download registry.pol file
        Invoke-WebRequest -Uri $urlgpo -OutFile "$destinationPath\registry.pol" -ErrorAction Stop
        Write-Host "Successfully downloaded registry.pol" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download registry.pol. Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 2
    }

    Write-Output "Files successfully downloaded to $destinationPath"

    # Change directory to destination path for execution
    Set-Location $destinationPath

    try {
        # Apply LGPO settings
        .\LGPO.exe /m "$destinationPath\registry.pol" /v > "$destinationPath\lgpo-verbose.txt" 2> "$destinationPath\lgpo-error.txt"

        # Force Group Policy update
        gpupdate /force
        Write-Output "LGPO settings applied. Group Policy update completed." -ForegroundColor Green

        # Output Group Policy results
        gpresult /r > "$destinationPath\gpresult.txt"
        Write-Host "Saved gpresult output to gpresult.txt" -ForegroundColor Cyan

        # Export security settings
        secedit /export /cfg "$destinationPath\security.txt"
        Write-Host "Exported security configuration to security.txt" -ForegroundColor Cyan
        
    } catch {
        Write-Host "Implementation of registry.pol failed - Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 3
    }
}

# Update the Local GPO
Get-LGPO

