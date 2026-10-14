[CmdletBinding()]
param(
    [ValidateSet('x64', 'ARM64')][string]$Architecture,
    [Parameter(Mandatory = $true)][string]$Tag,
    [string]$SodiumSource
)
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$project = Join-Path $root 'windows/MeshDrop/MeshDrop.csproj'
$rid = 'win-' + $Architecture.ToLowerInvariant()
$publish = Join-Path $root "windows/artifacts/portable/$rid"
$release = Join-Path $root 'release-assets'
$extra = @()
if ($Architecture -eq 'ARM64') {
    if (!(Test-Path "$SodiumSource/builds/msvc/vs2022/libsodium/libsodium.vcxproj")) { throw 'Missing pinned libsodium 1.0.19 source.' }
    $native = Join-Path $root 'windows/artifacts/sodium-arm64'
    New-Item -ItemType Directory -Force $native | Out-Null
    & msbuild "$SodiumSource/builds/msvc/vs2022/libsodium/libsodium.vcxproj" `
        -p:Configuration=ReleaseDLL -p:Platform=ARM64 "-p:OutDir=$native\" -v:minimal
    if ($LASTEXITCODE -ne 0) { throw 'libsodium ARM64 build failed.' }
    Copy-Item "$SodiumSource/LICENSE" "$native/libsodium-LICENSE.txt"
    $extra = @("-p:CustomAfterMicrosoftCommonTargets=$PSScriptRoot/windows-arm64-runtime.targets", "-p:MeshDropSodiumDir=$native")
}
& msbuild $project -restore -t:Publish -p:Configuration=Release "-p:Platform=$Architecture" `
    "-p:RuntimeIdentifier=$rid" -p:WindowsPackageType=None -p:SelfContained=true `
    -p:WindowsAppSDKSelfContained=true -p:PublishTrimmed=false "-p:PublishDir=$publish\" @extra -v:minimal
if ($LASTEXITCODE -ne 0) { throw 'Windows portable build failed.' }
New-Item -ItemType Directory -Force $release | Out-Null
Copy-Item (Join-Path $root 'LICENSE') $publish
Compress-Archive -Path "$publish/*" -DestinationPath "$release/MeshDrop-$Tag-windows-$($Architecture.ToLowerInvariant()).zip" -Force
& msbuild $project -restore -t:Build -p:Configuration=Release "-p:Platform=$Architecture" `
    "-p:RuntimeIdentifier=$rid" -p:StorePackage=true @extra -v:minimal
if ($LASTEXITCODE -ne 0) { throw 'Windows Store build failed.' }
$packages = @(Get-ChildItem windows/artifacts/store -Recurse -Filter '*.msix')
if ($packages.Count -ne 1) { throw 'Expected one Store package.' }
Copy-Item $packages[0].FullName "$release/MeshDrop-$Tag-windows-$($Architecture.ToLowerInvariant())-store.msix"
