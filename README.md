# k8s-ucp-bootstrap

# How to run

## Pre-requisites  

Follow [Crossplane's tutorial](https://crossplane.io/docs/v1.8/getting-started/install-configure.html) on how to create credentials for **AWS** and **GCP**
- Store the AWS Credentials in: `repo-root/creds/creds-aws.conf`
- Store the GCP Credentials in: `repo-root/creds/creds-gcp.json`

## Start
```bash
$ make install-tools
$ make start
``` 
and follow the the instructions in the terminal.

# Tips
If you are running the core-cluster locally you can access the ArgoCD server on `https://argocd.localhost`. This is a more stable connection compared to port-forwarding.

