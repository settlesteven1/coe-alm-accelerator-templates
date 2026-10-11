# ALM Accelerator Templates: Modernization Plan (RYSE fork)

Fork of `microsoft/coe-alm-accelerator-templates`. Upstream `main` last moved on
2025-02-17 and `version.json` still says March 2024, so this fork has to carry
the toolchain forward on its own.

## Where it stands today

| Area | Current state | Problem |
|---|---|---|
| Canvas apps | `pac solution clone/sync --processCanvasApps`, plus a legacy shim that repacks old `.fx.yaml`/msapp folder layouts and a loader for the retired PowerAppsLanguageTooling DLLs | Canvas source should be the native Power Apps YAML (`.pa.yaml`) that the maker portal and `pac` now emit. The shims and DLL loader are dead weight. |
| pac CLI install | `nuget install Microsoft.PowerApps.CLI` in `install-pac.yml`, with a hand-maintained version dictionary | Windows-only, slow, and the version pin is stale. |
| Agents | `vmImage: windows-latest` everywhere | pac, PowerShell 7 and the Build Tools tasks all run on Linux now. Only `VSBuild` for plugin projects needs Windows. |
| Auth | Client secret passed as a plain argument to ~15 PowerShell calls | Secrets end up in logs and need rotation. Workload Identity Federation is supported by the Build Tools service connection. |
| Admin PowerShell | `Microsoft.PowerApps.Administration.PowerShell` 2.0.148 and `Microsoft.Xrm.Data.PowerShell` 2.8.14 for app ownership, sharing, consent bypass, flow activation | The admin module is superseded by `pac admin` / `pac connection` / `pac solution` commands and the Dataverse Web API. Both modules are Windows PowerShell 5.1 era. |
| Canvas tests | `CanvasTestFramework/` ships Selenium + `Microsoft.PowerApps.TestAutomation` DLLs, run via `VSTest@2` | That framework is abandoned. Power Apps Test Engine (`pac test run`) is the supported path. |
| Build Tools tasks | `PowerPlatform*@2` | Still current, but a couple of inputs changed and `PowerPlatformToolInstaller` can own the pac install. |
| Repo hygiene | Stray `jeschro-1540-readme.md`, no CI, Pester tests only runnable by hand | No way to know a change broke something until a pipeline runs. |

## Plan

Phases are ordered so each one leaves the templates working. Each phase is a PR.

### Phase 0: Baseline and safety net (first PR)
- Remove `jeschro-1540-readme.md`; move its caching notes into `docs/`.
- Add a GitHub Actions workflow that runs PSScriptAnalyzer over `PowerShell/`, yamllint over `Pipelines/`, and the existing Pester tests in `PowerShell/tests`.
- Add `CHANGELOG.md` and bump `version.json` to a fork version string.
- Decide branding: keep upstream file names so `sync-pipeline-repo.yml` and the ALM Accelerator app's template lookup still work.

### Phase 1: Toolchain
- Replace `install-pac.yml` with `PowerPlatformToolInstaller@2` as the single source of pac, or `dotnet tool install Microsoft.PowerApps.CLI.Tool` where the task is unavailable. Delete the nuget path and the version dictionary.
- Pin pac to a minimum version that emits `.pa.yaml` and expose it as one pipeline variable.
- Switch default `vmImage` to `ubuntu-latest`; keep a Windows pool only for the `build-run-unit-test-projects.yml` / `VSBuild` steps, and convert those to `dotnet build` where the plugin projects are SDK-style.
- Audit every `powershell:` step and change to `pwsh:` so scripts run on PowerShell 7 on any OS. Fix backslash path building (`Split("\")`, `"$x\y"`) with `Join-Path`.

### Phase 2: Canvas apps as YAML
- Treat `.pa.yaml` under `CanvasApps/src/<app>/Src` as the source of truth. `pac solution clone/sync --processCanvasApps` and `pac solution pack --processCanvasApps` already round-trip this format; the templates mostly need to stop fighting it.
- Delete `canvas-unpack-pack.ps1` (PowerAppsLanguageTooling loader) and `Invoke-Repack-Canvas-Apps`; rely on `pac solution pack --processCanvasApps` to rebuild msapps.
- Keep `Invoke-Process-Old-Canvas-Code-Folder-Structure` behind an opt-in parameter for one release as a migration aid, then remove.
- Add a validation step: `pac canvas validate` (or a pack dry-run) on PRs so a bad YAML edit fails before import.
- Document the maker loop: edit YAML in VS Code with the Power Apps YAML extension, PR, pipeline packs and deploys.

### Phase 3: Authentication
- Support Workload Identity Federation service connections. `PowerPlatformSetConnectionVariables@2` still exposes TenantId/ApplicationId; stop reading `ClientSecret` and instead have each PowerShell step acquire a token through `pac auth create` with the federated credential or through the task's emitted token.
- Thread one access token (already partly done via `set-spn-token.yml` / `MAPPED_SPN_Token`) into all Web API calls so no function signature takes a secret.
- Keep client secret as a fallback flag for tenants that have not moved, with a deprecation warning.

### Phase 4: Replace the admin PowerShell modules
Map each use of the admin module to a supported replacement:

| Today | Replacement |
|---|---|
| `Set-AdminPowerAppOwner` | `pac admin set-app-owner` (or Web API `canvasapps` / `SetOwner`) |
| `Set-AdminPowerAppRoleAssignment` | `pac admin share-app` / Web API |
| `Set-AdminPowerAppApisToBypassConsent` | `pac canvas bypass-consent` equivalent via admin API |
| `Get-AdminPowerAppConnection` | `pac connection list --json` |
| Flow activation and ownership (`Microsoft.Xrm.Data.PowerShell`) | Dataverse Web API `workflows` entity via existing `dataverse-webapi-functions.ps1` |
| Configuration Migration import | `pac data import` |

Remove `install-powershell-modules.yml` once nothing imports the modules; keep the cache task for the pac tools folder.

### Phase 5: Testing
- Replace `CanvasTestFramework/` and `run-canvas-tests.yml` with Power Apps Test Engine: `pac test run` against a test plan YAML stored next to the solution.
- Keep the solution checker step (`PowerPlatformChecker@2`) and let it fail PRs above a configurable severity.

### Phase 6: Platform direction (decide before investing further)
- Power Platform now has native Dataverse Git integration and Power Platform Pipelines. This repo already has `*-Pipelines.yml` variants that let Power Platform Pipelines call these templates as extensions. The fork should lean into that: the deploy side becomes thin, and the value of these templates is the pre/post hooks (ownership, sharing, flow activation, connection references, Power Pages).
- Decide whether `export-solution-to-git*.yml` stays (classic export-to-git) or becomes optional for environments using native Git integration.
- Power Pages: confirm `export-Power-Page.yml` uses `pac pages download/upload` (enhanced data model), not the retired `pac paportal` commands.

## Out of scope for now
- GitHub Actions parity for the pipelines themselves (the templates are Azure DevOps YAML; only the CI lint workflow is GitHub Actions).
- Changes to the ALM Accelerator canvas app in `microsoft/coe-starter-kit`.

## Verification items to confirm before Phase 1 ships
- Exact pac version where `.pa.yaml` became the default for `--processCanvasApps`.
- Whether `PowerPlatformSetConnectionVariables@2` emits a usable token for WIF connections, or whether `pac auth create --applicationId ... --tenant ... --azureDevOpsFederated` is required.
- Current names of the `pac admin` subcommands for app ownership and sharing.
