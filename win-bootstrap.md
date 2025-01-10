# Deploy SE for Windows

**Please Read**
---
Running Mammoth SE on Windows is in **preview**, please read carefully if you plan to use it for production purposes.
---
- The connector process does not restart automatically after it is terminated
- Version update has to be performed manually

# 

# Install steps

- Download the [`se_bootstrap_win.bat`](se_bootstrap_win.bat) file from this repo, save it to a dedicated folder on the Windows PC that will be used as Service Edge.
- From Mammoth management portal, find the Service Edge's configuration, download the "Bootstrap script for Linux" file `bootstrap.sh` and save to the same folder. This file contain configuration and settings specific to this Service Edge and is required to continue the setup.
- *Optionally download the zip file [`win-bootstrap.zip`](win-bootstrap.zip) that contains runtime binary and save to the same folder. This step is optional because the setup script can download it as well.*
- Then run the `se_bootstrap_win.bat` either from a command window or by clicking it. It will ask for **Administrator** privilege automatically, and that's the last step of the installation.
- *Optionally check install components and clean up*
  - *Check the installation path at: `C:\ProgramData\Mammoth\se_win`*
  - *Check running process `mammothfrpc.exe`*
  - *Check the autostart task `schtasks /query /v /fo list /tn mammoth-se2-task`*
  - *Remove bootstrapping files no longer needed: Any files within the folder where you save/run the `se_bootstrap_win.bat` can be deleted at this point.*
