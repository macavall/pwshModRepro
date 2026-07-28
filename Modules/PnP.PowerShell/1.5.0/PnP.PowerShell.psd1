#
# Module manifest for module 'PnP.PowerShell'
#
# This is a MINIMAL STUB used only to reproduce a module-load failure caused by a
# corrupt (truncated) format file. It is NOT the real PnP.PowerShell module.
#
@{
    RootModule        = 'PnP.PowerShell.psm1'
    ModuleVersion     = '1.5.0'
    GUID              = '0b0430ce-d799-4f3b-a565-f0dca1f31e17'
    Author            = 'Repro'
    CompanyName       = 'Repro'
    Description       = 'Stub PnP.PowerShell module with a corrupt format file to reproduce a load failure.'
    PowerShellVersion = '5.1'

    # The corrupt format file. Processing this during module load throws:
    #   "Errors occurred while loading the format data file: ... Unexpected end of file"
    FormatsToProcess  = @('PnP.PowerShell.Format.ps1xml')

    FunctionsToExport = @('Connect-PnPOnline')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
