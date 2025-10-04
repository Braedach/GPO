function Set-Hostname {
    <#
    .SYNOPSIS
        Changes the hostname of a Windows 11 (24H2) system and schedules a restart.
    .DESCRIPTION
        This script changes the computer's hostname to the specified value
        and schedules a system restart in 120 seconds to apply the change.
    .PARAMETER NewHostname
        The new hostname to set for the computer
    .EXAMPLE
        Local: Set-Hostname "New-PC-Name"
        Remote: run set-hostname.ps1 "New-PC-Name"
    .NOTES
        Ensure you run this script with administrative privileges.
    
    #>

    param (
        [string]$NewHostname = $args[0]
    )

    if (-not $NewHostname) {
        Write-Error "NewHostname argument is required."
        return
    }

    try {
        Rename-Computer -NewName $NewHostname -Force -ErrorAction Stop
        shutdown.exe /r /t 180 /c "System restart scheduled in 3 minutes to apply hostname change."
    }
    catch {
        Write-Error "Failed to change hostname: $_"
    }
}

Set-Hostname
