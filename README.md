# OfferLetter_GenerateWordDoc — PnP.PowerShell Load Failure Repro

This is a minimal **PowerShell Azure Functions** app that reproduces a production
error where `Connect-PnPOnline` fails with a `CommandNotFoundException` because the
bundled `PnP.PowerShell` module cannot be loaded.

## The error being reproduced

```
System.Management.Automation.CommandNotFoundException: The 'Connect-PnPOnline'
command was found in the module 'PnP.PowerShell', but the module could not be
loaded due to the following error: [Errors occurred while loading the format data
file: C:\home\site\wwwroot\Modules\PnP.PowerShell\1.5.0\PnP.PowerShell.Format.ps1xml,
Error in file ...\PnP.PowerShell.Format.ps1xml: Unexpected end of file has occurred.
The following elements are not closed: TableColumnHeader, TableHeaders, TableControl,
View, ViewDefinitions, Configuration. Line 2446, position 7.]
```

## Root cause

The bundled format file
[Modules/PnP.PowerShell/1.5.0/PnP.PowerShell.Format.ps1xml](Modules/PnP.PowerShell/1.5.0/PnP.PowerShell.Format.ps1xml)
is **truncated / corrupt** — the XML ends mid-element at line 2446, leaving several
elements unclosed.

When `Connect-PnPOnline` is invoked, PowerShell auto-loads the `PnP.PowerShell`
module. During load it processes every file listed in the manifest's
`FormatsToProcess` entry (see
[PnP.PowerShell.psd1](Modules/PnP.PowerShell/1.5.0/PnP.PowerShell.psd1)). Parsing
the corrupt `.ps1xml` throws an "Unexpected end of file" error, which aborts the
**entire module load**. Because the module never finishes loading, the command it
was supposed to provide (`Connect-PnPOnline`) is not registered — so the failure
surfaces to the caller as a `CommandNotFoundException`, even though the real problem
is the corrupt format file.

## Project layout

```
proj3/
├── host.json                       # managedDependency disabled (see note below)
├── local.settings.json
├── profile.ps1
├── requirements.psd1
├── OfferLetter_GenerateWordDoc/
│   ├── function.json               # HTTP trigger
│   └── run.ps1                     # logs "Trying to connect pnp online", calls Connect-PnPOnline
└── Modules/
    └── PnP.PowerShell/
        └── 1.5.0/
            ├── PnP.PowerShell.psd1            # manifest -> FormatsToProcess: the corrupt ps1xml
            ├── PnP.PowerShell.psm1            # stub Connect-PnPOnline (never reached)
            └── PnP.PowerShell.Format.ps1xml   # TRUNCATED / corrupt (2446 lines)
```

> **Note:** Managed dependencies are **disabled** in [host.json](host.json) so the
> corrupt module bundled under `Modules/` wins module resolution. If managed
> dependencies were enabled and pulled a healthy `PnP.PowerShell` from the gallery,
> the error would not reproduce.

## Prerequisites

- [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- PowerShell 7.x
- An Azure Storage emulator (Azurite) or a real storage connection string, since
  `AzureWebJobsStorage` is set to `UseDevelopmentStorage=true`

## Reproduce

### Option A — Quick check (no Functions runtime)

Import the corrupt module directly to observe the format-load failure:

```powershell
Import-Module .\Modules\PnP.PowerShell\1.5.0\PnP.PowerShell.psd1 -Force
```

Observe the "Unexpected end of file ... Line 2446, position 7" error.

Then confirm the `CommandNotFoundException` wrapping by invoking the command in a
clean session that only sees this module path:

```powershell
pwsh -NoProfile -Command {
    $env:PSModulePath = "$PWD\Modules;$env:PSModulePath"
    Connect-PnPOnline -Url 'https://contoso.sharepoint.com'
}
```

### Option B — Full Functions app

1. Start the storage emulator (Azurite):
   ```powershell
   azurite
   ```
2. From this folder, start the app:
   ```powershell
   func start
   ```
3. Invoke the HTTP endpoint (the URL is printed by `func start`):
   ```powershell
   Invoke-RestMethod -Uri 'http://localhost:7071/api/OfferLetter_GenerateWordDoc'
   ```
4. The function logs `Trying to connect pnp online`, then returns **HTTP 500** with
   the full `CommandNotFoundException` — matching the production log.

## Resolution

The fix is to replace the corrupt format file with an intact copy of the module so
`FormatsToProcess` parses successfully.

### 1. Confirm the file is the culprit

```powershell
# A healthy PnP.PowerShell.Format.ps1xml is well-formed XML and ends with closing tags.
# Validate the bundled one:
try {
    [xml](Get-Content .\Modules\PnP.PowerShell\1.5.0\PnP.PowerShell.Format.ps1xml -Raw)
    'XML is valid'
} catch {
    "CORRUPT: $($_.Exception.Message)"
}
```

A corrupt file throws; a healthy file parses without error.

### 2. Replace the corrupt module (pick one)

**Option 1 — Use managed dependencies (recommended for Consumption/EP hosting).**
Remove the bundled module and let the platform manage it:

1. Delete the local copy:
   ```powershell
   Remove-Item .\Modules\PnP.PowerShell -Recurse -Force
   ```
2. Enable managed dependency in [host.json](host.json):
   ```json
   "managedDependency": { "enabled": true }
   ```
3. Add the module to [requirements.psd1](requirements.psd1):
   ```powershell
   @{
       'PnP.PowerShell' = '1.5.*'
   }
   ```

**Option 2 — Re-bundle a clean module copy (the fix applied in this repo).**
Replace the corrupt bundled module with an intact copy of the *same version* from
the PowerShell Gallery.

Run from the project root (`proj3/`):

```powershell
$modules = Join-Path $PWD 'Modules'

# 1. Remove the corrupt bundled module
Remove-Item (Join-Path $modules 'PnP.PowerShell') -Recurse -Force

# 2. Save a clean copy of the exact same version into .\Modules
Save-Module -Name PnP.PowerShell -RequiredVersion 1.5.0 -Path $modules -Force
```

Then re-validate the format file with the XML check from step 1:

```powershell
try {
    [xml](Get-Content .\Modules\PnP.PowerShell\1.5.0\PnP.PowerShell.Format.ps1xml -Raw) | Out-Null
    'XML: valid (well-formed)'
} catch {
    "XML: CORRUPT -> $($_.Exception.Message)"
}
```

And confirm the command now resolves from a clean session that only sees this
module path:

```powershell
pwsh -NoProfile -Command {
    $env:PSModulePath = "$PWD\Modules;$env:PSModulePath"
    $cmd = Get-Command Connect-PnPOnline -ErrorAction Stop
    "Connect-PnPOnline: available (from module $($cmd.ModuleName) $($cmd.Version))"
}
```

Expected output:

```
XML: valid (well-formed)
Connect-PnPOnline: available (from module PnP.PowerShell 1.5.0)
```

> After this fix the stub repro files (a hand-written `.psm1`/`.psd1` and the
> truncated `.ps1xml`) are replaced by the real module contents
> (`Common/`, `Core/`, `Framework/`, `PnP.PowerShell.dll-Help.xml`, a valid
> `.ps1xml`, and the real manifest). At runtime `Connect-PnPOnline` will now reach
> the authentication stage instead of failing to load — confirming the
> module-load problem is resolved.

### 3. Redeploy and verify

After deploying the fix, invoke the function again — `Connect-PnPOnline` should load
and the `CommandNotFoundException` should be gone.

## Why this happens in production

A truncated `.ps1xml` typically results from an **incomplete or interrupted
deployment** (e.g., a zip upload cut short, a partial file copy to
`C:\home\site\wwwroot`, or a corrupted package). Because the file is only parsed
when the module is first auto-loaded, the failure can appear well after deployment,
on the first request that calls into the module.

**Prevention:**
- Prefer **managed dependencies** or **run-from-package** deployment so module files
  are delivered atomically rather than copied piecemeal.
- Validate bundled `.ps1xml` files in CI with the `[xml]` parse check above.
