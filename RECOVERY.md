# Recovery and rollback

Read before staging an EFI wrapper. Save work, have a bootable Windows recovery USB, and keep verified copies of the original Microsoft boot manager and BCD outside the EFI partition. The test was conducted with a fully decrypted OS volume. If you use encryption, firmware/boot changes can require recovery credentials; that configuration was not tested here.

## From working Windows

Run the patched upstream `tools/Uninstall-GpuUnlockBoot.ps1` as administrator if the wrapper is still installed. Verify `EFI\Microsoft\Boot\bootmgfw.efi` against your saved original hash. On the successful test boot it was already restored automatically before Windows started.

Restore `EnableGpuFirmware` in the GPU's display-class registry key from your own backup: restore its original type/value if it existed, or remove only that value if it was previously absent. A subsequent normal boot applies the driver setting change. Do not delete the display-class key.

## Frozen display or Code 43

These occurred during earlier attempts. If injection halts with an error, do not bypass its checks. A frozen firmware screen did not always mean Windows was stopped: one attempt reached Windows audibly while the display stayed frozen. Avoid repeated blind forced restarts; they risk unsaved data and boot-file inconsistency. When recovery is necessary, power off and boot without injection. If normal boot cannot be restored, use the recovery USB.

## From a Windows recovery USB

Choose Repair your computer and Command Prompt. Use `diskpart` and `list volume` to identify the existing FAT32 EFI system partition; select that verified volume and assign an unused letter such as S. Partition numbers and drive letters vary. Do not format or delete partitions.

If the wrapper's saved Microsoft boot manager exists, restore it:

```text
copy /y S:\EFI\Microsoft\Boot\bootmgfw_ms.efi S:\EFI\Microsoft\Boot\bootmgfw.efi
```

If no usable backup exists, identify the real Windows volume by locating its Windows directory. Rebuild boot files only on the verified EFI partition:

```text
bcdboot <WindowsVolume>:\Windows /s S: /f UEFI
```

Replace the placeholder and EFI letter with the verified values. These are recovery procedures, not commands to run against an unidentified disk. No binary or boot backup from the author's machine is included or appropriate for your machine.
