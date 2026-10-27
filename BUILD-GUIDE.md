# Build it yourself on Windows

This guide builds the source snapshot used in the reported successful boot. It does **not** turn the loader into a universal RTX 2080 Ti installer: it still pins the ASUS GPU IDs, PCI slot and exact native GOP/firmware signatures from the tested system. A different motherboard, GOP revision or GPU can be rejected. Do not edit out preflight checks to force a boot. There is no tested support here for other RTX generations.

## 1. Install build requirements

Use Windows x64 with:

- Git for Windows (`git.exe` available in a new terminal).
- Python **3.12 or newer**, including pip and `python.exe` on PATH. Avoid the Microsoft Store execution-alias stub; `python --version` must actually run Python.
- **Visual Studio 2026 Build Tools** (18.x), with Desktop development with C++, MSVC x86/x64 build tools, and a Windows SDK. This is the compiler used for the reported build; the helper deliberately does not silently substitute VS2022.
- Internet access and ample free space for EDK2/submodules, compiler output and large NVIDIA input packages. Downloads may take several minutes. Firmware inputs keep their original licenses.

The helper fetches NASM through the upstream preparation tool. It also invokes the upstream firmware generator, which may install Python's `zstandard` package for your user. Review `Build-Local.ps1` and the pinned upstream tools before running downloaded code.

**Building does not require administrator rights.** It does not touch the registry, EFI partition, BIOS settings, boot entries or current GPU state. Use an ordinary terminal for the build. Administrator rights and recovery preparation only become relevant for installation.

## 2. Download this repository

Open PowerShell:

```powershell
git clone https://github.com/ThuGie/rtx2080ti-windows-unlock-report.git
cd rtx2080ti-windows-unlock-report
```

Downloading a source ZIP also works: extract it first, then run `build.bat` inside the extracted folder. Do not run it from inside the ZIP viewer.

## 3. Run the helper

Double-click **build.bat**, or from the repository folder run:

```powershell
.\build.bat
```

The default working directory is `C:\gpu-unlock-build`. It must not already exist. If your account cannot create a directory directly under C:, choose a new writable short folder without spaces, for example:

```powershell
.\build.bat -WorkDirectory D:\gpu-unlock-build
```

Use only letters, digits, underscores, hyphens and backslashes in the working path. EDK2's Windows scripts are sensitive to spaces. The downloaded report folder itself may have spaces; the helper's **build workspace** must not.

The helper:

1. Clones the Windows upstream and pins commit `f78a0fb9f0053e9beb744a536a95fccad7bc26c4`.
2. Checks and applies this report's exact source patch.
3. Finds VS2026 through `vswhere`, then clones edk2-stable202608 and its submodules.
4. Generates the original Turing firmware inputs using pinned upstream scripts.
5. Downloads the normal-finalization V67 payload from a pinned commit and verifies SHA256. It checks every generated `.bin` against the successful session's input hashes.
6. Rebuilds BaseTools with x86 MSVC, prepares the package and NASM, then compiles the x64 Turing EFI with VS2026.
7. Prints the output path and its SHA256. **It does not install it.**

Expected output for the default path:

```text
C:\gpu-unlock-build\nv_unlock_win\build\UnlockLoader-Turing.efi
C:\gpu-unlock-build\nv_unlock_win\assets\firmware\Turing\
```

The EFI hash may differ with compiler/environment details; the historical hash is evidence, not a requirement for a newly compiled EFI. Firmware input hashes must match. Keep the full firmware folder, including its NVIDIA license, with your local build.

To check only source download/pinning/patch application, without firmware downloads or compilation:

```powershell
.\build.bat -SourceOnly -WorkDirectory C:\gpu-unlock-source-check
```

That is a source check, **not a completed build**. The helper refuses to reuse/reset an existing workspace. After any failed attempt, keep the logs and select a new `-WorkDirectory`. Do not delete or overwrite an unrelated directory to satisfy the helper.

## 4. Check hardware before considering installation

Compare your configuration with the [tested system table](README.md#tested-system). Useful read-only commands:

```powershell
Get-CimInstance Win32_VideoController | Format-List Name,PNPDeviceID,DriverVersion,ConfigManagerErrorCode
Get-CimInstance Win32_BaseBoard | Format-List Manufacturer,Product
nvidia-smi -q
```

The tested GPU was `VEN_10DE&DEV_1E07&SUBSYS_866A1043`, at PCI `0000:01:00.0`, VBIOS `90.02.17.00.47`. The motherboard was MSI MS-7B10. Even matching product names do not prove matching firmware driver signatures. The runtime preflight remains authoritative. The preserved-GOP branch requires exact native graphics/text driver signatures compiled into the source.

Do not flash a VBIOS or change PCI IDs to match this guide. The build helper performs no such operation.

## 5. Optional one-shot installation: advanced, tested profile only

Read [RECOVERY.md](RECOVERY.md) first. Have a working recovery USB and verified backups. Save your work. The successful test used Secure Boot off, legacy/CSM disabled in both relevant BIOS options, native NVIDIA GOP and a fully decrypted Windows volume. The scripts do not validate every one of these conditions for you.

**GSP setting:** follow [REPRODUCTION.md](REPRODUCTION.md#gsp-driver-setting) to back up and set DWORD `EnableGpuFirmware=1` in the intended GPU's display-class registry key. Do not assume the subkey is `0000`. Setting this value alone does not unlock a stock GPU. Do not proceed with an unrecorded registry change.

Before staging, back up the actual original Microsoft boot manager from your verified EFI partition, record SHA256, and export BCD from an administrator terminal:

```powershell
bcdedit /export C:\your-backup-folder\BCD-export
```

Create your backup folder first; substitute your own path. Use the upstream `Common.ps1`/`Get-EspRoot` tooling or an explicitly identified EFI partition to locate the boot manager. Do not guess disk or partition numbers from this report. If a wrapper is already installed, inspect/restore it before staging another.

From **PowerShell as administrator**, for the default build location:

```powershell
$src = 'C:\gpu-unlock-build\nv_unlock_win'
& "$src\tools\Install-GpuUnlockBoot.ps1" `
    -LoaderEfi "$src\build\UnlockLoader-Turing.efi" `
    -FirmwareDir "$src\assets\firmware\Turing" `
    -DefaultAction skip -SkipScheduledTask
```

Do not add `-AlsoFallback`. The tested approach did not overwrite the fallback boot path or install an automatic reinstallation task. Confirm the installer succeeded and the ESP firmware directory contains `v67-tu102-normal-finalize.bin` in addition to the generated inputs. Match the configuration in [REPRODUCTION.md](REPRODUCTION.md#one-shot-staging-used-in-the-test), including the exact target PCI location. The loader must default to SKIP; do not set up automatic injection.

Fully shut down, power on, and press **I once** in the menu. If a guard fails, stop and recover; do not force continuation. If Windows initializes normally, verify error code 0, actual GSP firmware activation, the EFI log, restored boot-manager hash and compute throughput **on that same boot**. Do not mistake an EFI success message or a normal desktop for benchmark proof.

## 6. Benchmark and rollback

Follow [REPRODUCTION.md](REPRODUCTION.md#benchmark-reproduction) for the included compute and ComfyUI tests. Use the Python environment containing CUDA PyTorch for GEMM. Compare a stock baseline and the injected boot with identical settings; allow normal measurement noise. The report's 51–53% compute uplift does not imply the same application improvement.

The successful wrapper restored the original Microsoft boot manager before Windows started. This is a one-shot setup; no persistence is claimed. For driver/boot problems or to restore the GSP setting, follow [RECOVERY.md](RECOVERY.md).

## Troubleshooting the build

- **Workspace already exists:** use a fresh `-WorkDirectory`. The helper never resets your checkout.
- **VS2026 not found:** install 18.x C++ Build Tools and SDK, then reopen the terminal. VS Code is not a compiler installation.
- **Python error / Store popup:** fix `python.exe` PATH or disable the Windows Store execution alias. Confirm `python --version` and `python -m pip --version`.
- **Submodule/download failure:** keep the full error; check connectivity and disk space, then try a new workspace. Do not substitute an unverified firmware download.
- **Firmware hash mismatch:** stop. Upstream inputs or extraction may differ; investigate rather than disabling verification.
- **Build succeeds but preflight rejects hardware:** this is a compatibility mismatch, not a compiler problem. This source is intentionally specific to the reported profile.

When reporting a failure, include the failing stage and sanitized output, OS/compiler versions and GPU/board/VBIOS identifiers. Exclude tokens, personal paths, serial numbers, disk images, EFI backups and proprietary firmware blobs.

## Helper validation on 28 October 2026

- A fresh source-only checkout passed clone, exact commit checkout, patch preflight/application and `git diff --check`.
- A separate fresh full workspace passed dependency downloads, all firmware `.bin` hash comparisons, BaseTools rebuild and the final X64 DEBUG/VS2026 EFI compilation.
- The newly compiled EFI SHA256 was `3AEFFA2021408D09FF3E7EA1961DE63EA432451A5172DD65762618C492D230DB`. It was **not installed or boot-tested**. The original successful boot binary has its separate historical hash in the evidence manifest.
- The `build.bat -SourceOnly` entry point also passed using Windows PowerShell 5.1.

These checks used the existing host's VS2026, Python and NASM installations, with newly downloaded source/dependency trees and firmware inputs. They do not establish a clean Windows installation test, NASM downloader coverage, or compatibility with a different computer's firmware.
