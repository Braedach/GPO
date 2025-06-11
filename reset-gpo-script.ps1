<#
    Updated 2025-06-11

    Purpose:
    
    Allow for the resetting of the LGPO via Live response
    Script must be run as Administrator for testing if run locally - changes may be required in PowerShell permissions
    Major flaw discovered in the secedit policy mainly SECURITYPOLICY - fixing
    
    DO NOT RUN THE Reset-Secedit function at this time - its there to see the issue - its not tested fully yet.

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

# Force group policy update
gpupdate /force
Write-Host "Group Policy refreshed after security reset." -ForegroundColor Cyan


}

function Reset-Secedit {
    
    # Define paths
    $backupFile = "$env:SystemRoot\Security\Database\secedit-backup.sdb"
    $defaultTemplate = "$env:SystemRoot\inf\defltbase.inf"
    $securityDB = "$env:SystemRoot\Security\Database\secedit.sdb"


    # Backup current security settings (just in case)
    if (Test-Path $securityDB) {
        Copy-Item -Path $securityDB -Destination $backupFile -Force
        Write-Host "Backup of current security settings created at $backupFile" -ForegroundColor Yellow
    } else {
        Write-Host "No existing security database found. Proceeding with reset." -ForegroundColor Cyan
    }
    
    # Clear local security policies
    Write-Host "Purging existing security policies..." -ForegroundColor Red
    secedit /clearmgmt
    Write-Host "Security policies cleared." -ForegroundColor Green

    # Restore default security settings
    Write-Host "Restoring default Windows security posture..." -ForegroundColor Red
    secedit /configure /db $securityDB /cfg $defaultTemplate /verbose
    Write-Host "System security reset to default settings." -ForegroundColor Green

}



function Restart-Windows {
    # Force restart of Windows
    Restart-Computer -Force
}

# Call the appropriate functions - see note above on the Reset-Secedit function - DONT USE
Reset-GPO
# Reset-Secedit
Restart-Windows
