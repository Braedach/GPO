<#
    Updated 2025-06-11

    Purpose:
    
    Allow for the resetting of the LGPO via Live response
    Script must be run as Administrator for testing if run locally - changes may be required in PowerShell permissions
    Retested the script found multiple errors - have corrected
    Updated error checking - modified commands

    Code is set to reset the LGPO

#>

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

            try {
                # Force Group Policy update after reset
                gpupdate /force
                Write-Output "LGPO settings applied. Group Policy update completed." -ForegroundColor Green

                # Output Group Policy results after reset
                gpresult /r > "$destinationPath\gpresult.txt"
                Write-Host "Saved gpresult output to gpresult.txt" -ForegroundColor Cyan

                # Export security settings after reset
                secedit /export /cfg "$destinationPath\security.txt"
                Write-Host "Exported security configuration to security.txt" -ForegroundColor Cyan
        
            } catch {
                Write-Host "Implementation of registry.pol failed - Error: $($_.Exception.Message)" -ForegroundColor Red
                exit 3
            }
        } catch {
            Write-Host "Failed to delete folder: $folder. Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

}


function Restart-Windows {
    # Force restart of Windows
    Restart-Computer -Force
}

# Uncomment the below line to purge the LGPO and restart Windows - you cannot run a reset and an update at the same time.  Obvious really
Reset-GPO
Restart-Windows
