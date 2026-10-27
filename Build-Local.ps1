# SPDX-License-Identifier: GPL-2.0-only
[CmdletBinding()]
param(
    [string]$WorkDirectory = 'C:\gpu-unlock-build',
    [switch]$SourceOnly
)
$ErrorActionPreference = 'Stop'
function Native {
    param([string]$Exe, [string[]]$Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Exe failed (exit $LASTEXITCODE)." }
}
$work = [IO.Path]::GetFullPath($WorkDirectory)
# Upstream EDK2/cmd build scripts do not support arbitrary shell metacharacters or spaces.
if ($work -notmatch '^[A-Za-z]:\\[A-Za-z0-9_\\-]+$') {
    throw 'Choose a short absolute local path with no spaces or shell characters, e.g. C:\gpu-unlock-build.'
}
Get-Command git.exe -ErrorAction Stop | Out-Null
if (Test-Path -LiteralPath $work) { throw "Workspace already exists: $work. Choose a NEW -WorkDirectory; existing files are never reset or deleted." }
New-Item -ItemType Directory -Path $work | Out-Null
$source = Join-Path $work 'nv_unlock_win'
Native git @('clone','https://github.com/mirabarukaso/nv_unlock_win.git',$source)
Native git @('-C',$source,'checkout','--detach','f78a0fb9f0053e9beb744a536a95fccad7bc26c4')
$patch = Join-Path $PSScriptRoot 'patches\tested-tu102-windows.patch'
Native git @('-C',$source,'apply','--check',$patch)
Native git @('-C',$source,'apply',$patch)
Native git @('-C',$source,'diff','--check')
if ($SourceOnly) {
    Write-Host "Source preparation verified: $source"
    Write-Host 'No firmware download, compilation, registry change or boot modification was performed.'
    return
}
$python = (Get-Command python.exe -ErrorAction Stop).Source
Native $python @('-c','import sys; assert sys.version_info >= (3, 12), "Python 3.12+ required by this helper"')
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio 2026 C++ Build Tools and Windows SDK first (see BUILD-GUIDE.md).' }
$vs = & $vswhere -latest -products '*' -version '[18.0,19.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $vs) { throw 'Visual Studio 2026 MSVC x86/x64 tools not found. See BUILD-GUIDE.md.' }
$vs = @($vs)[0]
$vc32 = Join-Path $vs 'VC\Auxiliary\Build\vcvars32.bat'
$vc64 = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
foreach ($path in @($python,$vc32,$vc64)) {
    if ($path -match '[%&!^\r\n]') { throw 'Unsupported shell characters in tool installation path.' }
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing tool: $path" }
}
$edk = Join-Path $work 'edk2'
Native git @('clone','--branch','edk2-stable202608','--depth','1','https://github.com/tianocore/edk2.git',$edk)
Native git @('-C',$edk,'submodule','update','--init','--depth','1')
# This invokes upstream's pinned-input firmware generator. It may install zstandard
# for the selected Python and downloads large NVIDIA packages; no boot changes.
& (Join-Path $source 'tools\Build-GpuUnlockFirmware.ps1') -Arch Turing
$fw = Join-Path $source 'assets\firmware\Turing'
$payload = Join-Path $fw 'v67-tu102-normal-finalize.bin'
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/xrip/cmp50hx-unlock/df2fe11b370bb52cc314576d0f2f5ae47ce908f8/efi-unlock/blobs/v67_payload.bin' -OutFile $payload
if ((Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash -ne 'de7288bcfb80c2d4b259a59e823c926ba0a9adcab594219cc6802c94257ce271') {
    throw 'Normal-finalization payload SHA256 mismatch. Build stopped.'
}
# Verify all generated inputs against the successful session, not just filenames.
$expected = Get-Content (Join-Path $PSScriptRoot 'evidence\tested-artifact-hashes.json') -Raw | ConvertFrom-Json
foreach ($entry in $expected) {
    if ($entry.file -notlike '*.bin') { continue }
    $inputPath = Join-Path $fw $entry.file
    if (-not (Test-Path -LiteralPath $inputPath)) { throw "Missing firmware: $($entry.file)" }
    if ((Get-FileHash -LiteralPath $inputPath).Hash -ne $entry.sha256) { throw "Firmware differs from tested input: $($entry.file). No build performed." }
}
$batch = Join-Path $work 'compile.cmd'
@"
@echo off
call "$vc32"
if errorlevel 1 exit /b 1
set "PYTHON_COMMAND=$python"
cd /d "$edk"
call edksetup.bat Rebuild VS2026
if errorlevel 1 exit /b 1
call "$vc64"
if errorlevel 1 exit /b 1
set "VS2026_PREFIX=%VCToolsInstallDir%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$source\tools\Prepare-GpuUnlock.ps1" -Arch Turing -Edk2Path "$edk" -FetchNasm
if errorlevel 1 exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$source\tools\Build-GpuUnlockEfi.ps1" -Arch Turing -Edk2Path "$edk" -ToolChain VS2026 -SkipPrepare
exit /b %errorlevel%
"@ | Set-Content -LiteralPath $batch -Encoding ASCII
Native cmd.exe @('/d','/c',$batch)
$efi = Join-Path $source 'build\UnlockLoader-Turing.efi'
if (-not (Test-Path -LiteralPath $efi)) { throw 'Build produced no EFI application.' }
Get-FileHash -LiteralPath $efi
Write-Host "Build complete: $efi"
Write-Host "Firmware directory: $fw"
Write-Host 'Nothing was installed. Read BUILD-GUIDE.md and RECOVERY.md before any boot experiment.'
