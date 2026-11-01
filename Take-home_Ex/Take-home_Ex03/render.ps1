$ErrorActionPreference = 'Stop'
$previousLocale03 = $env:LC_ALL
try {
    $env:LC_ALL = 'English_United States.utf8'
    Push-Location (Resolve-Path (Join-Path $PSScriptRoot '../..'))
    try {
        quarto render Take-home_Ex/Take-home_Ex03/technical-report.qmd
        if ($LASTEXITCODE -ne 0) { throw 'Technical report render failed.' }
        Rscript Take-home_Ex/Take-home_Ex03/verify.R
        if ($LASTEXITCODE -ne 0) { throw 'Statistical verification failed.' }
        quarto render Take-home_Ex/Take-home_Ex03/executive-summary.qmd
        if ($LASTEXITCODE -ne 0) { throw 'Executive summary render failed.' }
        quarto render index.qmd
        if ($LASTEXITCODE -ne 0) { throw 'Home page render failed.' }
        if (Test-Path -LiteralPath '.git') {
            node scripts/sync-rendered-navigation.mjs
            if ($LASTEXITCODE -ne 0) { throw 'Navigation synchronization failed.' }
        }
    } finally { Pop-Location }
} finally { $env:LC_ALL = $previousLocale03 }
