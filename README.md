# k8s-ucp-bootstrap

![](docs/images/drawings_control-plane.png)

# How to run

## Pre-requisites  

- Run Docker with 12GB of RAM and 6 CPUs
- Store the AWS Credentials in: `repo-root/creds/creds-aws.conf`
- Store the GCP Credentials in: `repo-root/creds/creds-gcp.json`

Follow [Crossplane's tutorial](https://crossplane.io/docs/v1.8/getting-started/install-configure.html) on how to create credentials for **AWS** and **GCP**

## Start
```bash
$ make install-tools
$ make start
``` 
and follow the the instructions in the terminal.

# Tips
If you are running the core-cluster locally you can access the ArgoCD server on `https://argocd.localhost`. This is a more stable connection compared to port-forwarding.

