$ErrorActionPreference = 'Stop'
$previousLocale = $env:LC_ALL
try {
    $env:LC_ALL = 'English_United States.utf8'
    Push-Location (Resolve-Path (Join-Path $PSScriptRoot '../..'))
    try {
        quarto render Take-home_Ex/Take-home_Ex02/technical-report.qmd
        if ($LASTEXITCODE -ne 0) { throw 'Technical report render failed.' }
        Rscript Take-home_Ex/Take-home_Ex02/verify.R
        if ($LASTEXITCODE -ne 0) { throw 'Statistical verification failed.' }
        quarto render Take-home_Ex/Take-home_Ex02/executive-summary.qmd
        if ($LASTEXITCODE -ne 0) { throw 'Executive summary render failed.' }
        quarto render index.qmd
        if ($LASTEXITCODE -ne 0) { throw 'Home page render failed.' }
    } finally { Pop-Location }
} finally { $env:LC_ALL = $previousLocale }
