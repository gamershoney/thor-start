[CmdletBinding()]
param(
    [ValidateSet("0.1.0-beta.1")]
    [string]$Version = "0.1.0-beta.1"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = $PSScriptRoot
$buildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot "build"))
$buildDirectory = [IO.Path]::GetFullPath((Join-Path $buildRoot "release-$Version"))
$packageDirectory = Join-Path $buildDirectory "Thor-Start-$Version"
$distDirectory = Join-Path $projectRoot "dist"
$archivePath = Join-Path $projectRoot "dist\Thor-Start-$Version-win64.zip"
$iconPath = Join-Path $buildRoot "thor-start.ico"
$resourceFile = Join-Path $buildRoot "thor-start.res"
$previousLocation = Get-Location

if (-not $buildDirectory.StartsWith(
    $buildRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Unsafe release staging path: $buildDirectory"
}

Set-Location $projectRoot
try {
if (Test-Path -LiteralPath $buildDirectory) {
    Remove-Item -LiteralPath $buildDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $distDirectory | Out-Null

# Produce a multi-purpose Windows icon from the embedded PNG without requiring
# an external image utility.
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ThorNativeIcon {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr handle);
}
"@
$sourceImage = [System.Drawing.Image]::FromFile((Join-Path $projectRoot "icon.png"))
try {
    $bitmap = New-Object System.Drawing.Bitmap 256, 256
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.DrawImage($sourceImage, 0, 0, 256, 256)
        } finally {
            $graphics.Dispose()
        }
        $iconHandle = $bitmap.GetHicon()
        try {
            $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
            # thor-start.rc refers to build\thor-start.ico. Generate that exact
            # intermediate so the release also works from a pristine checkout.
            $stream = [System.IO.File]::Create($iconPath)
            try {
                $icon.Save($stream)
            } finally {
                $stream.Dispose()
            }
        } finally {
            [ThorNativeIcon]::DestroyIcon($iconHandle) | Out-Null
        }
    } finally {
        $bitmap.Dispose()
    }
} finally {
    $sourceImage.Dispose()
}

$odin = (Get-Command odin -ErrorAction Stop).Source
$resourceCompiler = (Get-Command rc.exe -ErrorAction Stop).Source
& $resourceCompiler /nologo "/fo$resourceFile" (Join-Path $projectRoot "thor-start.rc")
if ($LASTEXITCODE -ne 0) { throw "Resource compilation failed." }

& $odin test $projectRoot "-out:$buildDirectory\thor-start-tests.exe"
if ($LASTEXITCODE -ne 0) { throw "Tests failed." }

$executable = Join-Path $packageDirectory "thor-start.exe"
& $odin build $projectRoot -o:speed -subsystem:windows "-resource:$resourceFile" "-out:$executable"
if ($LASTEXITCODE -ne 0) { throw "Release build failed." }

# Odin may leave its linker object beside the executable. It is an intermediate,
# not part of the distributable package.
Get-ChildItem -LiteralPath $packageDirectory -Filter "*.obj" -File |
    Remove-Item -Force

Copy-Item (Join-Path $projectRoot "README.md") $packageDirectory
Copy-Item (Join-Path $projectRoot "fonts\Inter-LICENSE.txt") (Join-Path $packageDirectory "Inter-LICENSE.txt")

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath
}
Compress-Archive -Path (Join-Path $packageDirectory "*") -DestinationPath $archivePath

# Fail the build if packaging ever starts leaking intermediates or omits a
# required distributable file.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $actualEntries = @($archive.Entries | ForEach-Object FullName | Sort-Object)
    $expectedEntries = @("Inter-LICENSE.txt", "README.md", "thor-start.exe") | Sort-Object
    if (Compare-Object $expectedEntries $actualEntries) {
        throw "Release archive contains an unexpected file set: $($actualEntries -join ', ')"
    }
} finally {
    $archive.Dispose()
}

Write-Host "Release ready: $archivePath"
} finally {
    Set-Location $previousLocation
    if (Test-Path -LiteralPath $buildDirectory) {
        Remove-Item -LiteralPath $buildDirectory -Recurse -Force
    }
    foreach ($temporaryFile in @($iconPath, $resourceFile)) {
        if (Test-Path -LiteralPath $temporaryFile -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryFile -Force
        }
    }
    if ((Test-Path -LiteralPath $buildRoot) -and
        @(Get-ChildItem -LiteralPath $buildRoot -Force).Count -eq 0) {
        Remove-Item -LiteralPath $buildRoot -Force
    }
}
