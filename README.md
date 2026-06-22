# Windows System Health Repair

> **Testing note:** This was tested by me to be working. User experience may vary.

## One-click use

1. Extract the repository.
2. Double-click `Run-OneClick.bat`.
3. Approve the Windows administrator prompt.
4. Allow the complete supported Windows health workflow to finish.
5. Review the exit code and logs in `C:\ProgramData\WindowsSystemHealthRepair\Logs`.

The launcher runs `Repair-WindowsSystemHealth.ps1` in repair mode directly. There is no menu and Windows is not restarted automatically.

## PowerShell usage

```powershell
.\Repair-WindowsSystemHealth.ps1
.\Repair-WindowsSystemHealth.ps1 -Repair
.\Repair-WindowsSystemHealth.ps1 -Repair -WhatIf
```

The default script mode performs built-in Windows health checks. Repair mode uses the supported component and protected-file repair sequence and records every command result.

Exit codes: `0` success, `1` fatal error, `2` one or more warning or failure results.

Maintain a current backup and review the generated logs. MIT License.
