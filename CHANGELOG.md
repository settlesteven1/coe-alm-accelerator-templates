# Changelog

All notable changes to this fork. Upstream history before the fork point is in
`git log` and the upstream releases at
https://github.com/microsoft/coe-alm-accelerator-templates/releases.

## Unreleased

### Phase 0: baseline
- Forked from `microsoft/coe-alm-accelerator-templates` at commit `59abea3` (upstream main, 2025-02-17).
- Added `docs/MODERNIZATION-PLAN.md` describing the phased update plan.
- Moved the stray `jeschro-1540-readme.md` to `docs/pipeline-caching.md`.
- Added CI (`.github/workflows/ci.yml`): yamllint over `Pipelines/`, PowerShell parse check and PSScriptAnalyzer over `PowerShell/`, JSON parse of the schema and settings files.
- Made the upstream `pr-loop` end-to-end workflow manual-only; it depends on Azure DevOps secrets the fork does not have.
- Added `.gitattributes` to normalize line endings going forward.
- Set `version.json` to a fork version string.
