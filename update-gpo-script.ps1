<#
    Updated 2025-06-12

    Purpose:
    
    Allow for the updating of the LGPO via Live response
    Script must be run as Administrator for testing if run locally - changes may be required in PowerShell permissions
    Modify command to ensure only Machine has group policy applied

    THIS CODE DOES NOT YET INCLUDE THE secedit SECURITYPOLICY update section
    Testing is in process for the reset of the secedit SECURITYPOLICY
    This error was found lately and needs and will be addressed

    Code is set to update the LGPO
    Code if functionalized for isolation and testing
    
#>


function Get-WindowsEdition {
    $edition = (Get-WmiObject -Class Win32_OperatingSystem).OperatingSystemSKU
    # List of SKU numbers for Windows Home Editions
    $homeEditions = @(1, 2, 3, 4, 5, 98, 99)

    if ($homeEditions -contains $edition) {
        Write-Host "Unsupported Windows edition detected: Home Edition. Exiting script..." -ForegroundColor Red
        exit
    } else {
        Write-Host "Windows edition is valid for this operation." -ForegroundColor Green
    }
}


function Get-LGPO {

    # Variables
    $destinationPath = "C:\Program Files\GPO"
    $oldPath = "C:\Program Files\Sysinternals"
    $urltool = "https://raw.githubusercontent.com/Braedach/GPO/main/LGPO.exe"
    $urlgpo = "https://raw.githubusercontent.com/Braedach/GPO/main/registry.pol"

     $files = @{
    "LGPO.exe" = $urltool
    "registry.pol" = $urlgpo
    }


    # Ensure the GPO directory exists - purge it - create it if missing
    if (Test-Path $destinationPath) {
        # Remove all files (excluding subdirectories)
        Get-ChildItem -Path $destinationPath -File | Remove-Item -Force
        Write-Host "All files in $destinationPath have been deleted." -ForegroundColor Green
        }
    else {
        Write-Host "Directory does not exist: $destinationPath" -ForegroundColor Red
        New-Item -ItemType Directory -Path $destinationPath -Force
        Write-Host "Directory created: $destinationPath" -ForegroundColor Green
        }

    # Purge the old files due to the folder move
    $oldFiles = @("LGPO.exe", "registry.pol")
    foreach ($file in $oldFiles) {
        $path = "$oldPath\$file"
        if (Test-Path $path) {
            Remove-Item $path -Force
            Write-Host "Removed old $file from $oldPath" -ForegroundColor Yellow
        }
    }


    # Download all the files required - exit on failure
    try {
        foreach ($file in $files.Keys) {
            $url = $files[$file]
            $destination = "$destinationPath\$file"

            Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
            Write-Host "Successfully downloaded $file" -ForegroundColor Green
            }
        } 
    catch {
        Write-Host "Failed to download $file. Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Exiting script due to download failure." -ForegroundColor Red
        exit
        }

    Write-Host "Files successfully downloaded to $destinationPath" -ForegroundColor Green

    

    try {
        # Change directory to destination path for execution
        Set-Location $destinationPath
        # Run LGPO command and check success
        .\LGPO.exe /m $destinationPath\registry.pol /v > $destinationPath\lgpo-verbose.txt 2> $destinationPath\lgpo-error.txt

        # Force a Group Policy update
        gpupdate /force    
        Write-Host "LGPO settings applied. Group Policy update completed." -ForegroundColor Green
    
        }
    catch {
        Write-Host "Implementation of registry.pol failed - Error: $($_.Exception.Message)" -ForegroundColor Red
        exit
        }

}


function Get-Securitypolicy {
    # New function to fix the security policy that was found lacking
    # Insert code here once written
    
}

function Restart-Windows {
    # Force restart of Windows
    Restart-Computer -Force
}



# Call the appropriate functions - these need to be called in order
# Do NOT call the Get-Secedit function - its in testing and has issues
Get-WindowsEdition
Get-LGPO
# Get-Securitypolicy
Restart-Windows
