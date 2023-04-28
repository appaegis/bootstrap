# SE for Windows

**Warning**
---
Running Mammoth SE on Windows is experimental, it is not supported for production.

# 

# Install steps

- Copy zip file contains setup script and runtime binary to target Windows system
- After decompression, open a command window as **Administrator** and find the directory with the unzipped files.
- Next run the setup script: se_bootstrap_win.bat. Note you must provide the following parameters to se_bootstrap_win.bat:
```
auth_token
auth_secret
server_validation_code
server_addr
network_type
network_name
service_edge_number
proxyUrl (only if you connect the internet through proxy)
label (only if configured as devicemesh)
serialno (only if configured as devicemesh)
```

- You can get these parameters from the network bootstrap script of our admin console.
- Once the script is completed, your Windows should be running the SE as a service.

