[CmdletBinding()]
param(
    [ValidateSet('x64', 'ARM64')]
    [string]$Architecture = 'x64',
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v\d+\.\d+\.\d+(-(alpha|beta|rc)\.[1-9]\d*)?$')]
    [string]$Tag
)

$ErrorActionPreference = 'Stop'
$rid = 'win-' + $Architecture.ToLowerInvariant()
$project = Join-Path $PSScriptRoot 'MeshDrop\MeshDrop.csproj'
$publish = Join-Path $PSScriptRoot "artifacts\portable\$rid"
$release = Join-Path $PSScriptRoot 'artifacts\release'
$version = $Tag.Substring(1).Split('-')[0]
[xml]$source = Get-Content $project
if ($source.Project.PropertyGroup.Version -notcontains $version) {
    throw "Tag $Tag does not match the Windows project version."
}

& msbuild $project -restore -t:Publish -p:Configuration=Release "-p:Platform=$Architecture" `
    "-p:RuntimeIdentifier=$rid" -p:WindowsPackageType=None -p:SelfContained=true `
    -p:WindowsAppSDKSelfContained=true -p:PublishTrimmed=false "-p:PublishDir=$publish\" -v:minimal
if ($LASTEXITCODE -ne 0) { throw "Portable build failed ($LASTEXITCODE)." }
if (!(Test-Path (Join-Path $publish 'MeshDrop.exe'))) { throw 'Portable executable is missing.' }
if (!(Test-Path (Join-Path $publish 'resources.pri'))) { throw 'Localized resources are missing.' }

New-Item -ItemType Directory -Force -Path $release | Out-Null
$zip = Join-Path $release "MeshDrop-$Tag-windows-$($Architecture.ToLowerInvariant()).zip"
Compress-Archive -Path (Join-Path $publish '*') -DestinationPath $zip -Force

& msbuild $project -restore -t:Build -p:Configuration=Release "-p:Platform=$Architecture" `
    "-p:RuntimeIdentifier=$rid" -p:StorePackage=true -v:minimal
if ($LASTEXITCODE -ne 0) { throw "Store upload build failed ($LASTEXITCODE)." }
Write-Output $zip
