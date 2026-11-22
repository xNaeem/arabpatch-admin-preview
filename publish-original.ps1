param(
    [string]$PublicRepo = "xNaeem/arabpatch-admin-preview",
    [string]$SourceBranch = "design/posthog-luxury-preview-20261122"
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Run this file from a clean checkout of the PUBLIC preview repository.
$previewRepo = (Resolve-Path $PSScriptRoot).Path
$desktop = [Environment]::GetFolderPath('Desktop')
$source = Join-Path $desktop "ArabPatch-Design-Source"
$sourceUrl = "https://github.com/xNaeem/alw-website.git"
$previewRoot = ".publication/admin-rebuild-preview-20261118"
$buildPath = Join-Path $source "$previewRoot/dist"
$originalConfig = Join-Path $source "$previewRoot/astro.config.mjs"

function Run([string]$Exe, [string[]]$Params) {
    & $Exe @Params
    if ($LASTEXITCODE -ne 0) { throw "$Exe failed with code $LASTEXITCODE" }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required."
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js is required."
}

if (-not (Test-Path (Join-Path $previewRepo ".git"))) {
    throw "Run the script from a cloned arabpatch-admin-preview Git repository."
}
if (-not (Test-Path (Join-Path $source ".git"))) {
    Write-Host "Cloning the ORIGINAL Admin source into an independent design workspace..."
    Run "git" @("clone", "--depth", "1", "--branch", $SourceBranch, $sourceUrl, $source)
} else {
    Push-Location $source
    try {
        # Refuse to overwrite any personal work.
        $changes = & git status --porcelain
        if ($LASTEXITCODE -ne 0) { throw "Could not inspect the design source." }
        if ($changes) { throw "The design source has local changes. Nothing was overwritten." }
        Run "git" @("fetch", "origin", $SourceBranch, "--depth", "1")
        Run "git" @("checkout", $SourceBranch)
        Run "git" @("pull", "--ff-only", "origin", $SourceBranch)
    } finally { Pop-Location }
}

Push-Location $source
try {
    Write-Host "Installing dependencies only when necessary..."
    if (-not (Test-Path "node_modules/astro/bin/astro.mjs")) {
        Run "npm.cmd" @("ci")
    }
    # Temporarily adjust the ORIGINAL config in memory and restore its exact bytes.
    # Avoid '--config <absolute Unicode Windows path>', which Astro failed to resolve.
    $originalBytes = [IO.File]::ReadAllBytes($originalConfig)
    try {
        $originalText = [Text.Encoding]::UTF8.GetString($originalBytes)
        if (-not $originalText.Contains("export default defineConfig({")) {
            throw "Unexpected Astro config layout. The original file was not modified."
        }
        if (-not $originalText.Contains("site: 'http://127.0.0.1:5010'")) {
            throw "Unexpected local site setting. The original file was not modified."
        }
        $pagesConfig = $originalText.Replace(
            "site: 'http://127.0.0.1:5010'",
            "site: 'https://xnaeem.github.io',"
        )
        # Replace above adds a comma; the original site line already had one.
        $pagesConfig = $pagesConfig.Replace(
            "site: 'https://xnaeem.github.io',,",
            "site: 'https://xnaeem.github.io',"
        )
        $pagesConfig = $pagesConfig.Replace(
            "export default defineConfig({",
            "export default defineConfig({`n  base: '/arabpatch-admin-preview/',"
        )
        [IO.File]::WriteAllText($originalConfig, $pagesConfig, [Text.UTF8Encoding]::new($false))
        Write-Host "Building the original Astro Admin with GitHub Pages base..."
        Run "node" @("node_modules/astro/bin/astro.mjs", "build", "--root", $previewRoot)
    } finally {
        # The design source must remain unmodified even after a build failure.
        [IO.File]::WriteAllBytes($originalConfig, $originalBytes)
    }
} finally { Pop-Location }

if (-not (Test-Path (Join-Path $buildPath "index.html"))) {
    throw "The Astro build did not produce index.html. Nothing was deployed."
}

Write-Host "Preparing GitHub Pages output..."
# This public repo intentionally includes only compiled front-end files.
# Preserve the publishing script, .git directory, and GitHub workflows.
$generatedNames = @("index.html", "404.html", "_astro", "branding", "artwork", "assets", "fonts", "images", "media", "favicon.ico", "robots.txt", "sitemap.xml", ".nojekyll")
foreach ($name in $generatedNames) {
    $entry = Join-Path $previewRepo $name
    if (Test-Path -LiteralPath $entry) {
        Remove-Item -LiteralPath $entry -Force -Recurse
    }
}
Copy-Item -Path (Join-Path $buildPath "*") -Destination $previewRepo -Recurse -Force
$hiddenFile = Join-Path $previewRepo ".nojekyll"
Set-Content -LiteralPath $hiddenFile -Value "" -Encoding ascii

# Normalize hard-coded root-relative static asset URLs for project Pages base.
$files = Get-ChildItem -Path $previewRepo -Recurse -File -Include *.html,*.css,*.js
foreach ($file in $files) {
    if ($file.FullName -match '[\\/]\.git[\\/]') { continue }
    $text = [IO.File]::ReadAllText($file.FullName)
    $updated = [regex]::Replace(
        $text,
        '(["''(])/(?!/|arabpatch-admin-preview/)(?=(?:_astro|branding|artwork|assets|fonts|images|media)/)',
        '$1/arabpatch-admin-preview/'
    )
    if ($updated -cne $text) {
        [IO.File]::WriteAllText($file.FullName, $updated, [Text.UTF8Encoding]::new($false))
    }
}

Push-Location $previewRepo
try {
    Run "git" @("add", "-A")
    $staged = & git diff --cached --name-only
    if ($LASTEXITCODE -ne 0) { throw "Could not check the staged files." }
    if (-not $staged) {
        Write-Host "Already up to date."
    } else {
        Run "git" @("commit", "-m", "Publish original ArabPatch Admin Astro preview")
        Run "git" @("push", "origin", "main")
    }
} finally { Pop-Location }

Write-Host "SUCCESS: https://xnaeem.github.io/arabpatch-admin-preview/"
Write-Host "NOTE: GitHub Pages is static. Real admin APIs and email sends are unavailable."
