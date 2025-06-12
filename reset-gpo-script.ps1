<#
    Updated 2025-06-12

    Purpose:
    
    Allow for the resetting of the LGPO via Live response
    Script must be run as Administrator for testing if run locally - changes may be required in PowerShell permissions
    Major flaw discovered in the secedit policy mainly SECURITYPOLICY - fixing
    
    DO NOT RUN THE Reset-Secedit function at this time - its there to see the issue - its not tested fully yet.

    Code is set to reset the LGPO

#>

function Reset-GPO {
    param (
        [string]$RootPath = "C:\Windows\System32\",
        [string]$destinationPath = "C:\Program Files\GPO"
    )

    # Ensure the GPO directory exists - purge it - create it if missing
    if (Test-Path $destinationPath) {
        # Remove all files (excluding subdirectories)
        Get-ChildItem -Path $destinationPath -File | Remove-Item -Force
        Write-Host "All files in $destinationPath have been deleted." -ForegroundColor Green
    } else {
        Write-Host "Directory does not exist: $destinationPath" -ForegroundColor Red
        New-Item -ItemType Directory -Path $destinationPath -Force
        Write-Host "Directory created: $destinationPath" -ForegroundColor Green
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
        Write-Host "No Group Policy folders found. Checking Security Policy..." -ForegroundColor Yellow
        return
    }
    else {
         # Remove found folders
        foreach ($folder in $folders) {
            try {
                Remove-Item -Path $folder -Recurse -Force
                Write-Host "Deleted folder: $folder" -ForegroundColor Green
                } 
            catch {
            Write-Host "Failed to delete folder: $folder. Error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

   

    try {
        # Force group policy update
        gpupdate /force
        Write-Host "Group Policy being refreshed whether it exists or not..." -ForegroundColor Cyan

        # Output Group Policy results after reset
        gpresult /r > "$destinationPath\gpresult.txt"
        Write-Host "Saved gpresult output to gpresult.txt in $destinationPath" -ForegroundColor Cyan

        # Export security settings after reset
        secedit /export /cfg "$destinationPath\security-policy.txt"
        Write-Host "Exported security configuration to security-policy.txt in $destinationPath" -ForegroundColor Cyan
        
    } 
    catch {
        Write-Host "Reset of group policy failed - Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 3
    }



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
        # LOGIC ERROR -IF THERE IS NO DATABASE HOW CAN YOU RESET IT - MOVE THE CODE BLOCK
        # 
    }
    
    # Clear local security policies
    # THIS CODE SHOULD BE ADDED IN THE ABOVE ELSE BLOCK
    Write-Host "Purging existing security policies..." -ForegroundColor Red
    secedit /clearmgmt
    Write-Host "Security policies cleared." -ForegroundColor Green

    # Restore default security settings
    # LOGIC ERROR YOU NEED TO CHECK FOR EXISTANCE OF THE DEFAULT TEMPLATE FIRST
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
# Restart-Windows
