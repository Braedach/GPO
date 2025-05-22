<#
    Updated 2025-05-22

    Purpose:
    
    Allow for the updating of the LGPO via Live response
    Script must be run as Administrator for testing if run locally
    Retested the script found multiple errors - have corrected
    Updated error checking - modified commands

    Limitations - code only allows for a single (Computer policy - no user policy is defined) and as such the command reflects

#>

function Get-LGPO {

    # Variables
    $destinationPath = "C:\Program Files\Sysinternals"
    $urltool = "https://raw.githubusercontent.com/Braedach/GPO/main/LGPO.exe"
    $urlgpo = "https://raw.githubusercontent.com/Braedach/GPO/main/registry.pol"


    # Create the destination folder if it doesn't exist
    if (!(Test-Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force
    }

    try {
    # Download the appropriate files - handle network failures
    Invoke-WebRequest -Uri $urltool -OutFile "$destinationPath\LGPO.exe" -ErrorAction Stop
    Write-Host "Successfully downloaded LGPO.exe" -ForegroundColor Green
    } catch {
    Write-Host "Failed to download LGPO.exe. Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1  # Exit script with error code 1
    }

try {
    Invoke-WebRequest -Uri $urlgpo -OutFile "$destinationPath\registry.pol" -ErrorAction Stop
    Write-Host "Successfully downloaded registry.pol" -ForegroundColor Green
    } catch {
    Write-Host "Failed to download registry.pol. Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 2  # Exit script with error code 2
    }


    Write-Output "Files successfully downloaded to $destinationPath"

    # Change directory to destination path for execution
    Set-Location $destinationPath

   try {
    # Run LGPO command and check success
    .\LGPO.exe /m $destinationPath\registry.pol /v > $destinationPath\lgpo-verbose.txt 2> $destinationPath\lgpo-error.txt

    # Force a Group Policy update
    gpupdate /force    
    Write-Output "LGPO settings applied. Group Policy update completed." -ForegroundColor Green
    
    } catch {
    Write-Host "Implementation of registry.pol failed - Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 3  # Exit script with error code 2
    }

}



function Reset-GPO {
    param (
        [string]$RootPath = "C:\Windows\System32\"
    )

    # Ensure the provided path exists
    if (-not (Test-Path -Path $RootPath)) {
        Write-Host "The specified path does not exist: $RootPath" -ForegroundColor Red
        return
    }

        # Function to check for the presence of GroupPolicy folders
    function Get-GPOFolders {
        $foundFolders = @()
        foreach ($folder in @("GroupPolicy", "GroupPolicyUsers")) {
            $path = Join-Path -Path $RootPath -ChildPath $folder
            if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
                $foundFolders += $path
            }
        }
        return $foundFolders
    }

    $folders = Get-GPOFolders

    # Exit if neither folder is found
    if ($folders.Count -eq 0) {
        Write-Host "No Group Policy folders found. Exiting..." -ForegroundColor Yellow
        return
    }

    # Remove found folders
    foreach ($folder in $folders) {
        try {
            Remove-Item -Path $folder -Recurse -Force
            Write-Host "Deleted folder: $folder" -ForegroundColor Green
        } catch {
            Write-Host "Failed to delete folder: $folder. Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Force Group Policy update
    Invoke-Command { gpupdate /force }
}


Function Restart-Windows {
    # Force restart of Windows
    Restart-Computer -Force
}

# Uncomment the below line to purge the LGPO and restart Windows
# Reset-GPO
# Restart-Windows

# Update the Local GPO
Get-LGPO
