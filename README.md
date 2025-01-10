# How to deploy Service Edge for your platform

You can deploy Mammoth Cyber Service Edge (SE) on these platform.
The SE is a lightweight tunnel endpoint that connect back to your Mammoth Account automatically,
so that your users can access internal servers behind SE from the Mammoth Enterprise Browser.

| Platform  | Support Status | Deployment method |
| ------------- | ------------- | ------------- |
| Docker Engine on Linux | Supported  | docker-compose file |
| Docker Desktop on Mac  | Should work  | docker-compose file  |
| Docker Desktop on Windows | Not tested |  |
| Kubernetes | Supported | helm value file |
| Linux VM in public cloud | Supported | bootstrap script as userdata |
| [`Linux VM on VMware`](vmware-bootstrap.md) | Supported | bootstrap script as userdata |
| Generic Linux | Supported | bootstrap script |
| [`Windows Native Agent`](win-bootstrap.md) | Preview | bootstrap script |


## Dependencies
* Docker Engine 19.03 or later
* Docker Compose 2.3.4 or later
