
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


function reset-lgpo {

  <#
  .SYNOPSIS
      Resets the Local Group Policy on a Windows device
      Tested 2025-10-01

  .DESCRIPTION
      Resets the Local Group Policy on a Windows device
      Must be run as an elevated user if run locally.
      Issues may exist as the reset removes non Administator accounts from the system
      This is in testing and code has been added to address the problem but I cant guarantee the results yet.

  .PARAMETER NewHostname
      None
  #>
 
  [CmdletBinding()]
    param()
  

  # Backup (optional but recommended)
  $backupDir = "C:\GPOBackup_$(Get-Date -Format yyyyMMdd_HHmmss)"
  New-Item -Path $backupDir -ItemType Directory -Force
  Write-Host "Creating a backup in $backupDir"
  Copy-Item -Path "$env:windir\System32\GroupPolicy" -Destination $backupDir -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item -Path "$env:windir\System32\GroupPolicyUsers" -Destination $backupDir -Recurse -Force -ErrorAction SilentlyContinue

  # Remove Group Policy folders
  Write-Host "Removing the appropriate folders" -ForegroundColor Green
  Remove-Item -Path "$env:windir\System32\GroupPolicy" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "$env:windir\System32\GroupPolicyUsers" -Recurse -Force -ErrorAction SilentlyContinue

  # Remove common policy registry keys
  $regKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies",
    "HKCU:\Software\Policies",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies",
    "HKLM:\Software\Policies",
    "HKLM:\Software\WOW6432Node\Microsoft\Policies"
  )
  foreach($k in $regKeys){
    if(Test-Path $k){
      Remove-Item -Path $k -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Removing related registry keys" -ForegroundColor Green
  }

  # Reset Local Security Policy using the default INF
  Write-Output y | secedit /configure /cfg "$env:windir\inf\defltbase.inf" /db secedit.db /overwrite /verbose


  # Get all local accounts except built-in ones (Administrator, Guest, etc.)
  $localUsers = Get-LocalUser | Where-Object {
      -not $_.Disabled -and
      $_.Name -notin @('Administrator','Guest','DefaultAccount','WDAGUtilityAccount')
  }

  foreach ($u in $localUsers) {
      try {
          Add-LocalGroupMember -Group "Users" -Member $u.Name -ErrorAction Stop
          Write-Host "Restored $($u.Name) to Users group"
      }
      catch {
          Write-Warning "Could not add $($u.Name): $_"
      }
  }


  # Reapply and force policy update
  gpupdate /force

}

function restart-windows {
    # Restart Windows - notify the user
    # Notify user and restart
    $msg = "A major change has occured by the Network Administrator. The system will restart in 120 seconds. Please save your work."
    msg * $msg
    shutdown.exe /r /t 120 /c "Group policy removal completed. Restarting system."
    
}

get-windowsedition
reset-lgpo
restart-windows