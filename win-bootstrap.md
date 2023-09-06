# SE for Windows

**Please Read**
---
Running Mammoth SE on Windows is in **preview**, it is not recommended for production environment.

# 

# Install steps

- Copy zip file contains setup script and runtime binary to target Windows system
- After decompression, open a command window as **Administrator** and find the directory with the unzipped files.
- Next run the setup script: se_bootstrap_win.bat with parameters. **How to get these parameters:**
  1. From our admin console, find the Network and ServiceEdge you are trying to configure
  2. Copy the "Bootstrap script for Linux"
  3. Paste it to a Notepad on the Window PC you are trying to setup SE
  4. The original content will look like the first code block below, you need to remove the first two lines and change last line's command to "se_bootstrap_win.bat", but keep all the parameters.
```
#!/usr/bin/env bash
curl -fsSL https://raw.githubusercontent.com/appaegis/bootstrap/master/se_bootstrap.sh -o se_bootstrap.sh
bash se_bootstrap.sh "token" "secret" "token" "addr" "type" "nw name" "number"...
```
Edit into
```
se_bootstrap_win.bat "token" "secret" "token" "addr" "type" "nw name" "number"...
```

- Once the script is completed, your Windows should be running the SE as a service.

