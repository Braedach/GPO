<#
    Updated 2025-05-20

    Purpose:
    
    Allow for the updating of the LGPO via Live response
    Script must be run as Administrator for testing
    Currently testing and working

    Limitations - code only allows for a single (Computer policy - no user policy is defined)
                - no error checking code and the Reset-GPO function needs a bit of adjustment

#>

function Get-LGPO {
    $destinationPath = "C:\Program Files\Sysinternals"
    $urltool = "https://raw.githubusercontent.com/Braedach/GPO/main/LGPO.exe"
    $urlgpo = "https://raw.githubusercontent.com/Braedach/GPO/main/registry.pol"

    # Create the destination folder if it doesn't exist
    if (!(Test-Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force
    }

    # Download the appropriate files - no need to check as they will be overwritten
    Invoke-WebRequest -Uri $urltool -OutFile "$destinationPath\LGPO.exe"
    Invoke-WebRequest -Uri $urlgpo -OutFile "$destinationPath\registry.pol"

    Write-Output "Files successfully downloaded to $destinationPath"

    # Change directory to destination path for execution
    Set-Location $destinationPath

    # Run the LGPO command and capture output/errors
    .\LGPO.exe /g /v *> "$destinationPath\lgpo.out" 2> "$destinationPath\lgpo.err"

    # Force a Group Policy update
    gpupdate /force

    Write-Output "LGPO settings applied. Group Policy update completed."
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

# Uncomment the below line to purge the LGPO
# Reset-GPO

# Update the Local GPO
Get-LGPO
