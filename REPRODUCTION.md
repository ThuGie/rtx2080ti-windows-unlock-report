# Source and reproduction record

This records the actual tested process. It is not a turnkey installer. The public source patch retains exact machine guards; applying it on different hardware does not make that hardware supported.

## Source inputs and build

1. Clone https://github.com/mirabarukaso/nv_unlock_win and check out `f78a0fb9f0053e9beb744a536a95fccad7bc26c4`.
2. Apply `patches/tested-tu102-windows.patch` with `git apply`. The patch was verified against that exact base.
3. Prepare the upstream Turing firmware inputs using that project's documented tooling. The final build additionally expects `assets/firmware/Turing/v67-tu102-normal-finalize.bin`. Obtain the original `efi-unlock/blobs/v67_payload.bin` from https://github.com/xrip/cmp50hx-unlock at `df2fe11b370bb52cc314576d0f2f5ae47ce908f8`, verify SHA256 `de7288bcfb80c2d4b259a59e823c926ba0a9adcab594219cc6802c94257ce271`, then stage it under the new filename. Review upstream firmware terms yourself; no blob is included here.
4. The tested Booter, after removing the local package's 72-byte header, had a 59136-byte image with SHA256 `e0f0fc93da097b5b68e5af3adb58b2235ed1fad5fce0b23592d3895af44cb743`. Do not strip headers blindly: the local loader expects its packaged format. The tested local firmware filenames/hashes are in `evidence/tested-artifact-hashes.json`.
5. The tested build used edk2-stable202608, Visual Studio 2026 Build Tools, rebuilt EDK2 BaseTools and the upstream `tools/Build-GpuUnlockEfi.ps1 -Arch Turing -ToolChain VS2026`. A short mapped drive path avoided EDK2 issues with spaces. Set `VS2026_PREFIX` to your own `VCToolsInstallDir`. Follow upstream preparation requirements; this report does not vendor dependencies.

The successful local loader's hash is recorded as historical evidence, not as a downloadable binary. Different build environments need not produce byte-identical binaries. Compiling successfully does not validate a GPU transaction.

## GSP driver setting

In elevated PowerShell, identify the intended GPU's `PNPDeviceID` with `Get-CimInstance Win32_VideoController`. Its key under `HKLM:\SYSTEM\CurrentControlSet\Enum\<PNPDeviceID>` has a `Driver` value pointing to a display-class subkey, such as `{4d36e968-e325-11ce-bfc1-08002be10318}\0000`.

Back up whether `EnableGpuFirmware` exists, including its old type/value, in the corresponding key under `HKLM:\SYSTEM\CurrentControlSet\Control\Class\<Driver>`. Set `EnableGpuFirmware` to DWORD `1` in **that GPU's** key. Do not assume the instance is 0000 and do not change every display adapter. This change takes effect on a subsequent boot. Backups from the test machine are deliberately not published.

## One-shot staging used in the test

- A Windows recovery USB was ready, Secure Boot was off, the OS volume was decrypted and both legacy/CSM settings had been changed to UEFI/native GOP. Changing only one firmware CSM option had not produced the required native graphics path.
- Before installation, the existing Microsoft `bootmgfw.efi` was backed up and hashed, and BCD was exported. All firmware and loader hashes were checked.
- The patched upstream installer was invoked with the built Turing loader, its prepared firmware directory, `-DefaultAction skip -SkipScheduledTask`. The existing fallback `EFI\Boot\bootx64.efi` was left alone.
- The ESP configuration at `EFI\turing-unlock\config.ini` was:

```ini
default=skip
timeout_sec=20
verbose=1
targets=0000:01:00.0
```

- The user fully shut down, powered on and pressed **I once** in the loader menu. The tested path restores the original Microsoft boot manager before Windows handoff. No scheduled task reinstalled the injector.
- On that same successful boot, check `Get-CimInstance Win32_VideoController` for `ConfigManagerErrorCode = 0`, run `nvidia-smi`, and check `nvidia-smi -q` for actual GSP firmware activation. Here it reported `615.78.05`, rather than N/A.
- Archive the EFI log immediately and verify the Microsoft boot-manager hash against the saved original. The included handoff excerpt shows selectors `ss0=0x88888888`, `ss1=0x8` plus normal-finalization checks. Only a benchmark proves useful throughput after Windows initialization.

## Benchmark reproduction

Use the ComfyUI Python environment containing CUDA PyTorch:

```powershell
python benchmarks/gemm_fp16.py --sizes 4096,8192 --repeat 20
```

For image tests, run ComfyUI on 127.0.0.1:8188 with the models referenced by the included graphs installed. The scripts use only Python's standard library for API submission. Copy `benchmarks` to a new working folder or archive the supplied result JSON first: the runner intentionally refuses to overwrite evidence.

```powershell
python run-moss-benchmark.py --model moss --label unlocked
python run-moss-benchmark.py --model zimage --label unlocked
python compare-gsp-benchmarks.py
```

Unload models through ComfyUI's `/free` API between the two model tests. Do not run GEMM concurrently with image generation. The saved historical records are privacy-reduced to run/seed/wall time/status/timing events; full local graphs in those histories were omitted. The input graphs are provided separately. Models, ComfyUI custom nodes and their licenses are external dependencies.

No additional model download, global precision override or ComfyUI configuration change was required for the reported test. Z-Image's BF16 checkpoint was automatically executed as FP16 on Turing; this GPU has no native BF16 tensor hardware. Moss used its existing INT8 ConvRot weights. No claim of BF16 acceleration is made.
