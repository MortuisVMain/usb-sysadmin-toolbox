# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0-beta] - 2026-09-09

### Added
- System Doctor Module (`Invoke-SystemDoctor`): Automated 6-factor health scanner (SMART, RAM leaks, BSOD/WHEA crash analysis, DISM integrity, Battery wear, Network/DNS).
- Human-Readable Health Advisor: Translates cryptic error codes into plain Russian explanations with exact button recommendations for fixes.
- Safe Console Rendering: Sanitized multi-byte emojis for 100% universal compatibility with Windows 7/8/10/11 consoles.
- Institutional Memory: Documented diagnostic signature mappings in `003-automated-health-doctor-diagnostics.md`.

## [1.2.0-beta] - 2026-09-09

### Added
- Super-Admin 1-Click Launcher: Created `Toolbox.lnk` with embedded `SLDF_RUNAS_USER` UAC shield icon.
- Token Privilege Booster: Integrated Win32 API `AdjustTokenPrivileges` into `Toolbox.ps1` to unlock `SeDebugPrivilege`, `SeTakeOwnershipPrivilege`, `SeBackupPrivilege`.
- Working Directory Preservation: Fixed UAC elevation working directory reset bug in `Toolbox.bat`.
- Internal Self-Elevation Guard: Added automatic elevation directly inside `Toolbox.ps1`.
- Institutional Memory: Added solution record `002-windows-uac-elevation-and-token-privileges.md`.

## [1.1.0-beta] - 2026-09-09

### Refactored
- Architecture: Introduced unified `Invoke-Tool` DRY dispatcher for launching tools with path validation and automatic web fallback.
- Security: Sanitized Wi-Fi profile name arguments in `netsh` command to prevent argument injection.
- Reliability: Eliminated silent failures and unhandled empty `catch {}` blocks across network checks, TLS setup, and time sync.
- Institutional Memory: Added `docs/solutions/` database with solution record `001-powershell-encoding-and-compatibility.md`.
- Storage: Cleaned up 10 outdated software duplicates on USB flash drive.

## [1.0.0-beta] - 2026-08-21

### Added
- Modular architecture with `Toolbox.bat` auto-elevation launcher and `Toolbox.ps1` main interface.
- Complete categorization into 6 core sections with dynamic table view descriptions.
- Auto-detection of Operating System, architecture (x86/x64), and internet connectivity status.
- On-the-fly TLS 1.2 / TLS 1.3 protocol patching for Windows 7 SP1 and Windows 8.1.
- Emergency CMD Fallback mode for legacy systems (Windows XP / no PowerShell).
- Post-install suite: MAS activation, Chris Titus WinUtil, Win11Debloat, 1-click Winget essential apps installer, UniGetUI installer.
- Hardware & diagnostics: Laptop battery wear report (HTML), Wi-Fi saved password revealer, BSOD Minidump scanner, stress-test suite launcher, CrystalDiskInfo, Snappy Driver Installer.
- Cleanup & repair: Temp/prefetch cleaner, WinSxS component store compression (DISM), DDU driver uninstaller, auto-download for AdwCleaner and KVRT.
- Network & connectivity: Full network stack reset, Zapret for YouTube/Discord auto-downloader from GitHub, Time sync fix for SSL errors, Cloudflare and Google DNS switchers.
- System fixes: SFC & DISM repair, printer print spooler reset, .exe/.lnk file association recovery, Windows 10 classic context menu toggler, Administrator account activator, Windows 11 TPM/SecureBoot bypass.
- UEFI / BIOS direct reboot (`shutdown /r /fw /t 1`).
