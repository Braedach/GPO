

function Set-Hostname {

    <#
    .SYNOPSIS
        Changes the hostname of a Windows 11 (24H2) system and schedules a restart.
        Tested 2025-10-01

    .DESCRIPTION
        This function updates the computer's hostname to a user-specified value.
        It is designed to run in Microsoft Live Response or standard PowerShell.
        After changing the hostname, it notifies the logged-in user that the change
        has been applied and that the system will restart in 120 seconds.

    .PARAMETER NewHostname
        The new hostname to assign to the system.

    .EXAMPLE
        local: Set-Hostname -NewHostname "TRAINWEST-SRV01"
        live response: run Set-Hostname.ps1 -NewHostname "TRAINWEST-SRV01"

    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$NewHostname
    )

    try {
        # Change the hostname
        Rename-Computer -NewName $NewHostname -Force -ErrorAction Stop

        # Notify the user
        msg * "The hostname has been changed to '$NewHostname'. The system will restart in 120 seconds."

        # Schedule restart
        shutdown.exe /r /t 120 /c "System restart scheduled to apply hostname change."
    }
    catch {
        Write-Error "Failed to change hostname: $_"
    }
}

Set-Hostname
