# Stub implementation of Connect-PnPOnline.
#
# This body never actually runs in the repro: the module manifest lists a corrupt
# PnP.PowerShell.Format.ps1xml in FormatsToProcess, so module auto-load fails while
# parsing that XML before this function is ever made available. The result is the
# CommandNotFoundException for 'Connect-PnPOnline'.
function Connect-PnPOnline {
    [CmdletBinding()]
    param(
        [string] $Url,
        [string] $ClientId,
        [string] $Thumbprint,
        [string] $Tenant
    )

    Write-Output "Connected to $Url"
}
