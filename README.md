# Welcome to my portfolio

This repo houses a small selection of the various bits of script I have written over the years. Here you will find a selection of Powershell modules, scripts and functions, as well as some terraform pipelines.

## Highlights

If you want a quick digest of the top three things in here, it would be:

- **[Leavers-Automation.ps1](./Powershell/Scripts%20and%20Functions/Leavers-Automation.ps1)**
  - This mammoth script was designed to take a single csv input from an HR system and manage ending AD accounts. There is plenty of clever stuff in there, including some semi-intelligent error handling that logs tickets to the relevant support team.
- **[Azure Virtual Desktop Terraform pipeline](./Terraform/Azure%20Virtual%20Desktop/)**
  - This pipeline and module allows a full deployment of an AVD solution. This is designed to allow multiple  pools to be deployed and maintained via IaC.
- **[Set-WallpaperClock](./Powershell/PS%20Modules/Set-WallpaperClock/)**
  - This module was a personal project written as an adventure in publishing my own PS Module into the PSGallery. The module allows you to change your desktop wallpaper to a clean black background that displays the time, along with a few funky options.
