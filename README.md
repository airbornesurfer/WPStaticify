# WPStaticify
WordPress Staticify

Vibe-coded PowerShell script for exporting a locally-hosted WordPress website to static HTML/CSS/JS and preparing it for upload to remote web host.

Basically, it uses wget to download the site's contents, then searches through the downloaded files to locate referral/source URLs and changes them to match the web hosting address.

USAGE:

.\Export-ProjectGorbachev.ps1 -LocalWordPressUrl "http://project-gorbachev.local" -LiveStaticUrl "https://airbornesurfer.com/project-gorbachev" -OutputDirectory "project-gorbachev-static-live"
