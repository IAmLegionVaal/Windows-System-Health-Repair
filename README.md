# Windows System Health Repair

Single-run PowerShell diagnostics and repair for Windows component-store, protected-file and system-drive health.

> **Testing note:** This was tested by me to be working. User experience may vary.

## Included

`Repair-WindowsSystemHealth.ps1`

## Usage

Run diagnostic checks:

```powershell
.\Repair-WindowsSystemHealth.ps1
```

Run the supported repair sequence:

```powershell
.\Repair-WindowsSystemHealth.ps1 -Repair
```

Preview repair actions:

```powershell
.\Repair-WindowsSystemHealth.ps1 -Repair -WhatIf
```

Run PowerShell as Administrator. Timestamped command logs, a transcript and `Results.csv` are stored under:

```text
C:\ProgramData\WindowsSystemHealthRepair\Logs
```

## Behaviour

The default mode is diagnostic. Repair actions require the explicit `-Repair` parameter, respect `-WhatIf`, and do not restart the computer automatically.

Exit code `0` means success, `1` means a fatal error, and `2` means one or more checks returned a warning or failure result.

## Disclaimer

Use this project at your own risk. Results differ between Windows versions, devices, permissions and policies. Maintain a current backup and review the generated logs.

## License

MIT
