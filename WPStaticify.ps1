<#
.SYNOPSIS
    Downloads a WordPress site locally via wget and converts URLs for static deployment.

.DESCRIPTION
    This script uses wget (which must be installed and in your PATH) to recursively download
    a local WordPress instance. After downloading, it performs a find-and-replace operation
    to update all internal URLs in HTML, CSS, and JS files to point to your live static domain,
    supporting subdirectory deployments.

.PARAMETER LocalWordPressUrl
    The full URL of your local WordPress instance (e.g., "http://project-gorbachev.local").

.PARAMETER LiveStaticUrl
    The full base URL where your static site will be hosted (e.g., "https://airbornesurfer.com/project-gorbachev").

.PARAMETER OutputDirectory
    The name of the directory where the downloaded static site will be saved.
    (e.g., "static-gorbachev"). Defaults to "static-site-export".

.NOTES
    - Requires wget.exe to be installed and accessible in your system's PATH.
    - MAKE A BACKUP of your downloaded static site BEFORE running this script multiple times or
      if you are experimenting with URL replacements.
    - Ensure your local WordPress site is running when you execute this script.
    - This script uses UTF8 encoding for file operations.

.EXAMPLE
    .\Export-ProjectGorbachev.ps1 -LocalWordPressUrl "http://project-gorbachev.local" -LiveStaticUrl "https://airbornesurfer.com/project-gorbachev" -OutputDirectory "project-gorbachev-live"

#>

param(
    [Parameter(Mandatory=$true)]
    [string]$LocalWordPressUrl,

    [Parameter(Mandatory=$true)]
    [string]$LiveStaticUrl,

    [string]$OutputDirectory = "static-site-export"
)

# --- Configuration & Setup ---
Write-Host "`n--- Static Site Export & Conversion Script ---`n" -ForegroundColor Cyan

# Check for wget.exe
Write-Host "Checking for wget.exe..." -ForegroundColor DarkGray
try {
    if (-not (Get-Command wget.exe -ErrorAction SilentlyContinue)) {
        Write-Error "wget.exe not found in your system's PATH. Please install it (e.g., via Chocolatey 'choco install wget') and try again."
        exit 1
    }
    Write-Host "wget.exe found." -ForegroundColor DarkGreen
} catch {
    Write-Error "An error occurred while checking for wget.exe: $($_.Exception.Message)"
    exit 1
}

# Ensure URLs don't have trailing slashes for consistent replacement
$LocalWordPressUrl = $LocalWordPressUrl.TrimEnd('/')
$LiveStaticUrl = $LiveStaticUrl.TrimEnd('/')

$DownloadPath = Join-Path -Path (Get-Location) -ChildPath $OutputDirectory

# Create output directory
Write-Host "Creating output directory: $DownloadPath" -ForegroundColor DarkGray
if (Test-Path -Path $DownloadPath) {
    Write-Warning "Output directory '$OutputDirectory' already exists. Content might be overwritten if --no-clobber permits."
} else {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

Set-Location -Path $DownloadPath # Change to the download directory for wget

# --- Step 1: Download the Entire Site using wget ---
Write-Host "`n--- Step 1: Downloading site via wget ---`n" -ForegroundColor Yellow
Write-Host "Starting wget from $LocalWordPressUrl into '$DownloadPath'..." -ForegroundColor Green
Write-Host "This may take a while depending on your site size and local server speed." -ForegroundColor DarkGray

try {
    # wget command (using backticks for line continuation in PowerShell)
    # Define the arguments for wget in an array
    $wgetArgs = @(
        "--recursive",
        "--level=1",
        "--no-clobber",
        "--page-requisites",
        "--remote-encoding=UTF-8",
        "--local-encoding=UTF-8",
        "--html-extension",
        "--convert-links",
        "--restrict-file-names=windows",
        "--domains=$($LocalWordPressUrl.Replace('http://', '').Replace('https://', ''))",
        "--no-parent", # This argument specifically caused the error
            $LocalWordPressUrl # The starting URL
)

Write-Host "Executing wget with arguments: $($wgetArgs -join ' ')" -ForegroundColor DarkGray

# Use the call operator (&) to execute wget.exe with the argument array
& wget.exe @wgetArgs | Write-Host # This pipes wget's output to the console for display

Write-Host "`nwget download complete!" -ForegroundColor DarkGreen
} catch {
    Write-Error "wget download failed: $($_.Exception.Message)"
    exit 1
}

# --- Step 2: Perform URL Conversion ---
Write-Host "`n--- Step 2: Converting URLs in downloaded files ---`n" -ForegroundColor Yellow

# Define file types to process
$fileTypes = "*.html", "*.htm", "*.css", "*.js", "*.xml" # Added .htm and .xml for completeness

# Navigate into the wget-created folder (e.g., "project-gorbachev.local")
# The folder name will be based on the domain part of $LocalWordPressUrl
$domainFolderName = ($LocalWordPressUrl.Split('/') | Select-Object -Last 1).Split(':')[0] # Extracts "project-gorbachev.local" from URL
$downloadedSiteRoot = Join-Path -Path $DownloadPath -ChildPath $domainFolderName

if (-not (Test-Path -Path $downloadedSiteRoot)) {
    Write-Error "Could not find the downloaded site root at '$downloadedSiteRoot'. URL conversion cannot proceed."
    exit 1
}

Set-Location -Path $downloadedSiteRoot # Change to the root of the downloaded site for replacement

Write-Host "Searching for and replacing URLs in files within '$downloadedSiteRoot'..." -ForegroundColor Green

try {
    # Get all specified file types and perform replacement
    Get-ChildItem -Path . -Include $fileTypes -Recurse | ForEach-Object {
        $filePath = $_.FullName
        # Read raw content, replace, and set content back
        (Get-Content -Path $filePath -Raw) -replace [regex]::Escape($LocalWordPressUrl), $LiveStaticUrl | Set-Content -Path $filePath -Force -Encoding UTF8
        Write-Host "  Processed: $($_.Name)" -ForegroundColor DarkGray
    }

    # Handle root-relative links if necessary (e.g., "/about/" to "/project-gorbachev/about/")
    # This is a common requirement for subdirectory deployment if wget doesn't catch them.
    # Be cautious with this, as it can sometimes replace too broadly.
    # $OldRootRelative = "/"
    # $NewRootRelative = "/project-gorbachev/" # Replace with your actual subdirectory path including leading/trailing slashes if needed
    # Get-ChildItem -Path . -Include $fileTypes -Recurse | ForEach-Object {
    #     $filePath = $_.FullName
    #     (Get-Content -Path $filePath -Raw) -replace [regex]::Escape($OldRootRelative), $NewRootRelative | Set-Content -Path $filePath -Force -Encoding UTF8
    # }
    # Write-Host "  Processed root-relative links (if any)." -ForegroundColor DarkGray

    Write-Host "`nURL conversion complete!" -ForegroundColor DarkGreen

} catch {
    Write-Error "URL conversion failed: $($_.Exception.Message)"
    exit 1
}

# --- Step 3: Correct mojibakes ---

Write-Host "`n--- Step 3: Correcting mojibakes in HTML files ---`n" -ForegroundColor Yellow

# Define the find and replace pairs for common UTF-8 mojibake
# All characters are defined using their Unicode escape codes,
# making the entire script completely type-able.
$replacements = @{
    # Em-dash
    ([char]0x00e2 + [char]0x20ac + [char]0x2014) = [char]0x2014
    # En-dash
    ([char]0x00e2 + [char]0x20ac + [char]0x2013) = [char]0x2013
    # Curly Apostrophe
    ([char]0x00e2 + [char]0x20ac + [char]0x2019) = [char]0x2019
    # Opening Single Quote
    ([char]0x00e2 + [char]0x20ac + [char]0x2018) = [char]0x2018
    # Opening Double Quote
    ([char]0x00e2 + [char]0x20ac + [char]0x201c) = [char]0x201c
    # Closing Double Quote
    ([char]0x00e2 + [char]0x20ac + [char]0x201d) = [char]0x201d
    # Euro Sign
    ([char]0x00e2 + [char]0x20ac + [char]0x20ac) = [char]0x20ac
}

# Get all the HTML files in the current directory and its subdirectories
Get-ChildItem -Path . -Recurse -Filter "*.html" | ForEach-Object {
    $filePath = $_.FullName
    Write-Host "Correcting characters in: $filePath"

    # Read the file content as a single string.
    $content = Get-Content -Path $filePath -Raw -Encoding UTF8

    # Loop through the replacements and apply each one
    foreach ($oldString in $replacements.Keys) {
        $newString = $replacements[$oldString]
        $content = $content.Replace($oldString, $newString)
    }

    # Write the corrected content back to the file.
    # Set-Content should default to UTF8 without BOM in modern PowerShell
    # but we'll be explicit to be safe.
    Set-Content -Path $filePath -Value $content -Encoding UTF8 -Force
}

Write-Host "`n--- Script Finished ---`n" -ForegroundColor Cyan
Write-Host "Your static site is ready in: $downloadedSiteRoot" -ForegroundColor Green
Write-Host "Please review the content and prepare for upload to your server." -ForegroundColor Yellow
