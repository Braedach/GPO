<#
    Updated 2025-06-12

    Purpose:
    
    Allow for the resetting of the LGPO via Live response
    Script must be run as Administrator for testing if run locally - changes may be required in PowerShell permissions
    Major flaw discovered in the secedit policy mainly SECURITYPOLICY - fixing
    Strip the error codes and replace with text
    
    DO NOT RUN THE Reset-Secedit function at this time - its there to see the issue - its not tested fully yet.

    Code is set to reset the LGPO and Security Policy
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

function Reset-GPO {
    param (
        [string]$RootPath = "$env:SystemRoot\System32\",
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
        Write-Host "Group Policy appears to be not configured on this endpoint" -ForegroundColor Yellow
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
                <#Do this if a terminating exception happens#>
                Write-Host "Failed to delete folder: $folder. Error: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "Code has failed - find the error - exiting..." -ForegroundColor Red
                exit
            }
        }
    }

   

    try {
        # Group policy folders have been removed so should be cleared
        # Force group policy update
        gpupdate /force
        Write-Host "Group Policy being refreshed..." -ForegroundColor Cyan

        # Output Group Policy results after reset
        gpresult /H "$destinationPath\report.html"
        gpresult /r > "$destinationPath\gpresult.txt"
        Write-Host "Saved GPO Reports to  $destinationPath" -ForegroundColor Green

    } 
    catch {
        <#Do this if a terminating exception happens#>
        Write-Host "Reset of group policy failed - Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Group policy reset of endpoint has failed.  Check code..." - -ForegroundColor Red
        exit
    }

}

function Reset-Secedit {
    param (
        [string]$RootPath = "$env:SystemRoot\System32\",
        [string]$destinationPath = "C:\Program Files\GPO"
    )
    
    # Define paths
    $backupFile = "$env:SystemRoot\Security\Database\secedit-backup.sdb"
    $defaultTemplate = "$env:SystemRoot\inf\defltbase.inf"
    $securityDB = "$env:SystemRoot\security\database\secedit.sdb"
    $seceditlog = "$destinationPath\database-reset.log"

    # Backup current security settings (just in case)
    if (Test-Path $securityDB) {
        Copy-Item -Path $securityDB -Destination $backupFile -Force
        Write-Host "Backup of current security settings created at $backupFile" -ForegroundColor Yellow

        # Restore default security settings
        Write-Host "Restoring default Windows security posture..." -ForegroundColor Red

        # Check if the default security template exists
        if (Test-Path $defaultTemplate) {
            Write-Host "Default security template found..." -ForegroundColor Green

            try {
                # Be really careful not to stuff with areas you dont want to go
                # It might be easier to delete the database and force a restart but this has issues with standard user accounts
                # The restart would be the last line to be executed on this approach
                secedit /import /db %windir%\security\database\secedit.sdb /cfg %windir%\inf\defltbase.inf
                secedit /configure /db %windir%\security\database\secedit.sdb /verbose

                Write-Host "System security reset to default settings." -ForegroundColor Green
                } 
            catch {
                <#Do this if a terminating exception happens#>
                Write-Host "Error: Failed to apply default security template - $($_.Exception.Message)" -ForegroundColor Red
                exit
                }

        try {
            # Clear local security policies
            Write-Host "Purging existing security policies..." -ForegroundColor Yellow
            secedit /clearmgmt
            Write-Host "Security policies cleared." -ForegroundColor Green

            # Export security settings after reset
            secedit /export /cfg "$destinationPath\security-policy.txt"
            Write-Host "Exported security configuration to security-policy.txt in $destinationPath" -ForegroundColor Cyan
        
            }
        catch {
            <#Do this if a terminating exception happens#>
            Write-Host "Error: Purging existing security policies has failed.  $($_.Exception.Message) Code failure..." -ForegroundColor Red
            }
        }


    } else {
        Write-Host "Error: No existing security database found..." -ForegroundColor Red
        Write-Host "Error: Security Policy reset has failed - $($_.Exception.Message) Check code..." -ForegroundColor Red
        exit
    }
    
}

function Restart-Windows {
    # Force restart of Windows
    Restart-Computer -Force
}

# Call the appropriate functions - these need to be called in order
# Do NOT call the Reset-Secedit function - its in testing and has issues
Get-WindowsEdition
Reset-GPO
# Reset-Secedit
Restart-Windows
