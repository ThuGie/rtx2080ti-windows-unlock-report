# RTX 2080 Ti tensor unlock on Windows 11: tested configuration and results

A successful **single-machine Windows boot and benchmark report**, with the exact source patch used for the successful EFI build. This is an experimental, board/firmware-specific research snapshot, not a general Windows installer or a promise of compatibility.

On this system, the patched pre-boot loader plus NVIDIA display-class `EnableGpuFirmware=1` allowed Windows to initialize the GPU successfully. `nvidia-smi -q` reported GSP firmware **615.78.05**, Device Manager error code was **0**, and FP16 matrix throughput increased by approximately **51–53%** against earlier stock measurements.

## Tested system

| Component | Tested configuration |
|---|---|
| GPU | ASUS GeForce RTX 2080 Ti, stock 11 GB VRAM, TU102 |
| PCI IDs | 10de:1e07, subsystem 1043:866a |
| VBIOS | 90.02.17.00.47 |
| Motherboard | MSI MEG Z390 GODLIKE, MS-7B10 |
| CPU / RAM | Intel Core i9-9900K / 32 GB |
| OS | Windows 11 Pro, build 26200 |
| NVIDIA driver | Studio 617.42 / Windows 32.0.16.1742 |
| Boot configuration | UEFI, legacy/CSM disabled; native nvgop-tu1xx; Secure Boot off |
| Encryption | Windows volume fully decrypted during testing |
| Power | Existing 260 W limit; no power-limit or clock increase applied |
| Compute environment | PyTorch 2.12.1+cu130, CUDA 13.0 |
| Test session | Night of 27–28 October 2026, Europe/Amsterdam |

## Measured results

| Workload | Stock | Successful injected boot | Result |
|---|---:|---:|---|
| FP16 GEMM, 4096 cubed | 56.5 TFLOPS | 85.3 TFLOPS | 51.0% more throughput |
| FP16 GEMM, 8192 cubed | 54.0 TFLOPS | 82.8 TFLOPS | 53.3% more throughput |
| Z-Image Turbo, 768x768, 9 Euler steps | 7.797 s | 6.611 s | 17.9% more throughput / 15.2% less time |
| Moss Image SFT INT8 ConvRot, 768x768, 20 Euler steps | 35.916 s | 36.446 s | 1.5% longer; no demonstrated benefit |

Image times are ComfyUI server execution times, including decoding and saving. Each model ran three times with seeds 208011–208013; reported warm means exclude the first loading run. CUDA GEMM uses FP16 inputs/output with FP32 accumulation. Baselines came from an earlier stock boot, not a randomized repeated A/B experiment. The scripts, graphs, timing events and aggregate data are in [benchmarks](benchmarks/). Files named `unlocked` in this repository refer to the final successful GSP-enabled boot; earlier unsuccessful attempts are excluded.

All six image runs completed and the driver remained at error code 0 afterwards. Spot temperature readings reached 56 C; observed power readings stayed below the existing 260 W limit. These are short tests, not long-term reliability validation. The EFI success message alone was **not** treated as proof: driver health, actual GSP activation and the compute uplift were checked separately.

## What changed

The starting point was [mirabarukaso/nv_unlock_win](https://github.com/mirabarukaso/nv_unlock_win), commit `f78a0fb9f0053e9beb744a536a95fccad7bc26c4`. The [source patch](patches/tested-tu102-windows.patch) includes:

- TU102 normal-finalization payload selection and verification of restored privilege/WPR state.
- SEC2/GSP engine cleanup with selector retention checks; no post-unlock PCI function reset on the successful path.
- Hardware-specific native GOP ownership preflight. **The successful path preserves GOP ownership**, silences firmware display logging after preparation and validates handoff state. It does not detach the display drivers.
- Stop-on-failure checks instead of continuing into Windows after a failed injection, plus durable append-only boot logging.
- A one-shot boot-manager handoff and an installer change that leaves the fallback EFI path alone unless explicitly requested.

The decisive last configuration change was enabling the NVIDIA display-class DWORD `EnableGpuFirmware=1`. Previous attempts, including normal finalization and preserved GOP, reached Windows with **Code 43**. After applying this setting, the driver initialized and the benchmark uplift appeared. This is strong evidence for this configuration, not a controlled isolation of every preceding change or proof that the registry setting alone unlocks a stock GPU.

The setting was found in the related [CMP50HX Windows installer source](https://github.com/xrip/cmp50hx-unlock/blob/df2fe11b370bb52cc314576d0f2f5ae47ce908f8/efi-unlock-windows/tools/inst50hx/main.go). No modified NVIDIA driver, BYOVD package or mining-driver bundle was installed for this successful test.

## Build it yourself

Start with [BUILD-GUIDE.md](BUILD-GUIDE.md). The included **build.bat** / **Build-Local.ps1** clones pinned source, applies the patch, fetches and verifies firmware inputs, prepares EDK2 and compiles the loader. Building does not install anything or change your boot configuration. The hardware-specific compatibility restrictions still apply.

## How it was done

See [REPRODUCTION.md](REPRODUCTION.md) for source/build inputs, firmware provenance, staging procedure and verification. See [RECOVERY.md](RECOVERY.md) before experimenting with boot files.

**No automatic persistence was installed.** The wrapper restored the original Microsoft boot manager before handing off to Windows; its hash was verified afterwards. The GSP registry setting persists, but the tested unlock should not be assumed to survive an ordinary reboot. No reboot-persistence result is claimed.

## Scope and risk

Repeated earlier attempts caused frozen firmware screens, Code 43 and low-resolution single-monitor fallback. Recovery required restarting or powering off. Boot-chain and GPU firmware experiments can also make a system unbootable or cause data loss; no claim of hardware safety follows from one successful session. A recovery USB and verified boot-manager backups were available throughout.

The source deliberately pins this GPU's PCI IDs, location and exact firmware driver signatures. Other motherboard firmware versions may fail preflight. Do not remove guards merely to bypass a mismatch. There are no prebuilt EFI applications, NVIDIA firmware blobs, VBIOS dumps, disk images, private registry backups or complete machine logs in this publication.

## Credits and licensing

This is a report and adaptation of existing research, not the original discovery. Source patch: GPL-2.0, matching the patched project's LICENSE. Newly authored report and benchmark material in this repository is also GPL-2.0. External firmware inputs retain their own terms and are not distributed here.

- [mirabarukaso/nv_unlock_win](https://github.com/mirabarukaso/nv_unlock_win): Windows EFI implementation and benchmark foundation.
- [Zagitta/gpu-unlock](https://github.com/Zagitta/gpu-unlock): GPU-unlock research and Linux implementation.
- [haohervchb/Turing-unlock](https://github.com/haohervchb/Turing-unlock): same-board TU102 finalization reference; its source is not vendored here.
- [xrip/cmp50hx-unlock](https://github.com/xrip/cmp50hx-unlock): original V67 input and Windows GSP-setting reference.
- [PantACRO4life/gpu-unlock-4090-windows](https://github.com/PantACRO4life/gpu-unlock-4090-windows): comparison of Windows handoff strategies.
- CMP40HX-Unlock, CMP 90HX work and Jon Pry's V67 research: upstream exploit lineage; see the linked projects' original notices.
