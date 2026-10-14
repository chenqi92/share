[CmdletBinding()]
param(
    [ValidateSet('x64', 'ARM64', 'x86')]
    [string]$Architecture = 'x64'
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'generate-app-icon.ps1')
& (Join-Path $PSScriptRoot 'generate-store-assets.ps1')
$rid = 'win-' + $Architecture.ToLowerInvariant()
$project = Join-Path $PSScriptRoot 'MeshDrop\MeshDrop.csproj'
& dotnet build $project -c Release --nologo -v:minimal `
    "-p:Platform=$Architecture" -r $rid -p:StorePackage=true
if ($LASTEXITCODE -ne 0) { throw "Store package build failed ($LASTEXITCODE)." }

Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'artifacts\store') -Recurse -File |
    Where-Object Extension -in '.msixupload', '.appxupload', '.msix', '.appx' |
    Select-Object FullName, Length
