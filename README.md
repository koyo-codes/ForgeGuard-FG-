\# ForgeGuard (FG)



\*\*ForgeGuard\*\* is a PowerShell script that monitors your GPU temperature and automatically suspends/resumes \[Stable Diffusion Forge Neo](https://github.com/Haoming02/sd-forge-neo) to protect your GPU from overheating.



\---



\## Features



\- Monitors GPU hotspot temperature in real time

\- Automatically suspends Forge Neo when temperature reaches the threshold

\- Automatically resumes Forge Neo when temperature drops

\- Works with AMD and NVIDIA GPUs

\- Auto-installs LibreHardwareMonitor if not already installed



\---



\## Requirements



\- Windows 10 or later

\- PowerShell 5.1 or later (pre-installed on Windows)

\- \[Stable Diffusion Forge Neo](https://github.com/Haoming02/sd-forge-neo)

\- winget (pre-installed on Windows 10/11)



\---



\## Installation



1\. Download `ForgeGuard.ps1`

2\. Right-click → \*\*Run with PowerShell\*\*



LibreHardwareMonitor will be installed automatically on first run.



\---



\## Usage



1\. Start Forge Neo first

2\. Run `ForgeGuard.ps1`

3\. ForgeGuard will monitor your GPU temperature every 2 seconds

4\. Press `Ctrl+C` to quit



```

================================================

&#x20; ForgeGuard v1.0

&#x20; STOP  : 90 C or above

&#x20; RESUME: 60 C or below

&#x20; Check interval: 2 sec

&#x20; Press Ctrl+C to quit

================================================

\[12:00:00] \[RUNNING]  GPU: 78C

\[12:00:05] HOT: 91C (>=90C) -> Suspending Forge Neo...

&#x20; \[OK] Process suspended (PID: 12345)

&#x20; \[PAUSED] Waiting for temp to drop below 60C...

\[12:05:00] COOL: 58C (<=60C) -> Resuming Forge Neo...

&#x20; \[OK] Process resumed (PID: 12345)

```



\---



\## Configuration



Open `ForgeGuard.ps1` in a text editor and edit the settings section at the top:



```powershell

$TempStop      = 90   # Suspend when GPU reaches this temperature (C)

$TempResume    = 60   # Resume when GPU drops to this temperature (C)

$CheckInterval = 2    # How often to check temperature (seconds)

```



\---



\## How it works



ForgeGuard uses \[LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor) to read GPU temperature, and Windows NT API (`NtSuspendProcess` / `NtResumeProcess`) to freeze and unfreeze the Forge Neo process. Generation resumes exactly where it left off.



\---



\## License



MIT License - feel free to use, modify, and distribute.



\---



\## Credits



\- \[LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor) - MPL-2.0

