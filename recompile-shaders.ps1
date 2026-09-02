[CmdletBinding()]
param(
    [string] $FxcPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$shaderSource = Join-Path $projectRoot 'hlsl\defshader.hlsl'

if (-not (Test-Path -LiteralPath $shaderSource -PathType Leaf)) {
    throw "Shader source not found: $shaderSource"
}

if (-not $FxcPath) {
    $fxcCommand = Get-Command 'fxc.exe' -ErrorAction SilentlyContinue
    if ($fxcCommand) {
        $FxcPath = $fxcCommand.Source
    }
}

if (-not $FxcPath) {
    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $sdkBinRoot = Join-Path $programFilesX86 'Windows Kits\10\bin'

    if (Test-Path -LiteralPath $sdkBinRoot -PathType Container) {
        $FxcPath = Get-ChildItem -LiteralPath $sdkBinRoot -Directory |
            Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
            ForEach-Object {
                @(
                    (Join-Path $_.FullName 'x64\fxc.exe'),
                    (Join-Path $_.FullName 'x86\fxc.exe')
                )
            } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1
    }
}

if (-not $FxcPath -or -not (Test-Path -LiteralPath $FxcPath -PathType Leaf)) {
    throw 'fxc.exe was not found. Install the Windows SDK, add fxc.exe to PATH, or pass -FxcPath.'
}

$shaders = @(
    @{ Entry = 'RenderV';    Target = 'vs_5_0'; Output = 'ui_vertex.cso' },
    @{ Entry = 'RenderP';    Target = 'ps_5_0'; Output = 'ui_pixel.cso' },
    @{ Entry = 'RenderIcon'; Target = 'ps_5_0'; Output = 'icon_pixel.cso' }
)

$temporaryOutputs = @()

try {
    foreach ($shader in $shaders) {
        $finalPath = Join-Path $projectRoot $shader.Output
        $temporaryPath = "$finalPath.tmp"
        $temporaryOutputs += $temporaryPath

        Write-Host "Compiling $($shader.Entry) -> $($shader.Output)"
        & $FxcPath /nologo /T $shader.Target /E $shader.Entry /Fo $temporaryPath $shaderSource

        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
            throw "fxc.exe failed while compiling $($shader.Entry) (exit code $LASTEXITCODE)."
        }
    }

    foreach ($shader in $shaders) {
        $finalPath = Join-Path $projectRoot $shader.Output
        Move-Item -LiteralPath "$finalPath.tmp" -Destination $finalPath -Force
    }

    Write-Host 'Shaders recompiled successfully.' -ForegroundColor Green
}
finally {
    foreach ($temporaryPath in $temporaryOutputs) {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}
