# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanieddependency for additional information.
#
# NOTE: Managed dependency is DISABLED in host.json for this repro so that the
# corrupt, bundled PnP.PowerShell module under .\Modules wins module resolution.
# Do NOT add PnP.PowerShell here or a working copy would be downloaded and the
# error would not reproduce. 
@{
    # 'Az' = '11.*'
}
