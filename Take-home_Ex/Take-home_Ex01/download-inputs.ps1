$ErrorActionPreference = 'Stop'
$dataRoot = Join-Path $PSScriptRoot 'data/raw'
New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
$zipPath = Join-Path $dataRoot 'thailand-road-accident-fatalities-2024.zip'
$csvPath = Join-Path $dataRoot 'kaggle/thailand_road_accident_fatalities_2024.csv'
$boundaryPath = Join-Path $dataRoot 'geoBoundaries-THA-ADM1.geojson'
if (-not (Test-Path -LiteralPath $zipPath)) {
    Invoke-WebRequest -Uri 'https://www.kaggle.com/api/v1/datasets/download/pornsakkamchan/thailand-road-accident-fatalities-2024?datasetVersionNumber=1' -OutFile $zipPath
}
if (-not (Test-Path -LiteralPath $csvPath)) {
    Expand-Archive -LiteralPath $zipPath -DestinationPath (Join-Path $dataRoot 'kaggle')
}
if (-not (Test-Path -LiteralPath $boundaryPath)) {
    Invoke-WebRequest -Uri 'https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/THA/ADM1/geoBoundaries-THA-ADM1.geojson' -OutFile $boundaryPath
}
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'notes/input-manifest.json') -Raw | ConvertFrom-Json
foreach ($entry in $manifest.files) {
    $actual = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $entry.path) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry.sha256) { throw "Input hash differs from the verified version: $($entry.path)" }
}
Write-Output 'Original input files are present and their SHA-256 hashes match.'
