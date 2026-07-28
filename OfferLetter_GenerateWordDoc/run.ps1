using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# This function reproduces the PnP.PowerShell module load failure seen in production:
#
#   System.Management.Automation.CommandNotFoundException: The 'Connect-PnPOnline'
#   command was found in the module 'PnP.PowerShell', but the module could not be
#   loaded due to the following error: [Errors occurred while loading the format
#   data file: ...\Modules\PnP.PowerShell\1.5.0\PnP.PowerShell.Format.ps1xml,
#   Error in file ...: Unexpected end of file has occurred. The following elements
#   are not closed: TableColumnHeader, TableHeaders, TableControl, View,
#   ViewDefinitions, Configuration. Line 2446, position 7.
#
# The root cause is a TRUNCATED / corrupt PnP.PowerShell.Format.ps1xml bundled with
# the module under .\Modules\PnP.PowerShell\1.5.0. When PowerShell auto-loads the
# module (triggered by calling Connect-PnPOnline below), it processes the module's
# FormatsToProcess entry, fails to parse the corrupt XML, and the whole module load
# is aborted -- surfacing as a CommandNotFoundException for Connect-PnPOnline.

$tenantId  = '1e766028-aa76-420d-904e-a95ea5a54dd3'
$siteUrl   = 'https://farmersuat.sharepoint.com/sites/OfferLetters'
$clientId  = '00000000-0000-0000-0000-000000000000'
$thumbprint = 'F9515236B3EE1DE16EE8667CB0C80E1486120A55'

Write-Information "INFORMATION: Tenant Id $tenantId"
Write-Information "INFORMATION: Trying to connect pnp online"

$body = "OfferLetter_GenerateWordDoc executed."
$statusCode = [HttpStatusCode]::OK

try {
    # Auto-loads the corrupt PnP.PowerShell module -> triggers the ps1xml parse failure.
    Connect-PnPOnline -Url $siteUrl -ClientId $clientId -Thumbprint $thumbprint -Tenant $tenantId
}
catch {
    Write-Error "INFORMATION: $($_.Exception.ToString())"
    $body = $_.Exception.ToString()
    $statusCode = [HttpStatusCode]::InternalServerError
}

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode
    Body       = $body
})
