# Changelog

All notable changes to this project will be documented in this file.

## [0.9.0-beta] - 2026-08-20

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
