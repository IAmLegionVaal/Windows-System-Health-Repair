# Windows System Health Repair

PowerShell checks and supported repair actions using DISM, SFC and CHKDSK.

## One-click use

1. Extract the repository.
2. Double-click `Run-OneClick.bat`.
3. Approve the administrator prompt.
4. Review logs under `C:\ProgramData\WindowsSystemHealthRepair\Logs`.

The launcher runs repair mode. It never restarts Windows automatically.

## Usage

```powershell
# Checks only
.\Repair-WindowsSystemHealth.ps1

# Repair mode
.\Repair-WindowsSystemHealth.ps1 -Repair

# Preview
.\Repair-WindowsSystemHealth.ps1 -Repair -WhatIf
```

## Results

The script records each command's full output and classifies DISM, SFC and CHKDSK separately.

| Status | Meaning |
|---|---|
| `Pass` | No issue reported |
| `Repaired` | The tool reports a successful repair |
| `RestartRequired` | Offline work or a Windows restart is required |
| `Warning` | Follow-up review is required |
| `Fail` | The command failed or left an unresolved issue |
| `Unknown` | The command completed but its result text was not recognized reliably |

Known English result messages are classified. Localized or unexpected output becomes `Unknown` rather than a false pass.

Each run creates individual command logs, `Results.csv`, `Results.json` and a transcript.

## Exit codes

| Code | Meaning |
|---:|---|
| `0` | Every result is Pass or Repaired |
| `1` | Fatal script error |
| `2` | Warning, Fail, Unknown or RestartRequired result present |

## Validation

GitHub Actions uses PowerShell's native parser and PSScriptAnalyzer for every pull request and push to `main`.

## License

MIT License.
