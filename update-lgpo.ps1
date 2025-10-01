


function get-windowsedition {

    <#
    .SYNOPSIS
      Checks the Windows Edition is compliant
      Tested 2025-10-01

    .DESCRIPTION
      Checks the Windows Edition is compliant
      If not the code will exit
    #>


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




function get-lgpo {

    <#
    .SYNOPSIS
    Automates the download, application, and reporting of Local Group Policy settings using LGPO.exe.

    .DESCRIPTION
    This function performs the following tasks:
    1. Ensures the target GPO directory exists and is clean.
    2. Downloads LGPO.exe and registry.pol from a specified GitHub repository.
    3. Applies the registry.pol settings using LGPO.exe.
    4. Forces a Group Policy update.
    5. Generates Group Policy result reports in HTML and text formats.

    The function exits on download or execution failure to ensure integrity.
    #>

    # Variables
    $destinationPath = "C:\Program Files\GPO"
    $urltool = "https://raw.githubusercontent.com/Braedach/GPO/main/LGPO.exe"
    $urlgpo = "https://raw.githubusercontent.com/Braedach/GPO/main/registry.pol"

    $files = @{
        "LGPO.exe"     = $urltool
        "registry.pol" = $urlgpo
    }

    # Ensure the GPO directory exists - purge it - create it if missing
    if (Test-Path $destinationPath) {
        Get-ChildItem -Path $destinationPath -File | Remove-Item -Force
        Write-Host "All files in $destinationPath have been deleted." -ForegroundColor Green
    }
    else {
        Write-Host "Directory does not exist: $destinationPath" -ForegroundColor Red
        New-Item -ItemType Directory -Path $destinationPath -Force
        Write-Host "Directory created: $destinationPath" -ForegroundColor Green
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
        Set-Location $destinationPath
        .\LGPO.exe /m $destinationPath\registry.pol /v > $destinationPath\lgpo-verbose.txt 2> $destinationPath\lgpo-error.txt

        gpupdate /force    
        Write-Host "LGPO settings applied. Group Policy update completed." -ForegroundColor Green

        gpresult /H "$destinationPath\report.html"
        gpresult /r > "$destinationPath\gpresult.txt"
        Write-Host "Saved GPO Reports to $destinationPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Implementation of registry.pol failed - Error: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
}


function restart-windows {
    # Restart Windows - notify the user
    # Notify user and restart
    $msg = "A major change has occured by the Network Administrator. The system will restart in 120 seconds. Please save your work."
    msg * $msg
    shutdown.exe /r /t 120 /c "Group policy update completed. Restarting system."
    
}

# Updates the Local Group Policy Object using LGPO.exe and a predefined registry.pol file
get-windowsedition
Get-lgpo
restart-windows
