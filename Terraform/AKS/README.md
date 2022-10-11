# AKS Cluster provisioning pipeline

This pipeline was built for the sole purpose of provisioning an AKS cluster for an afternoon.

Yes you could do this in the UI, but why bother doing that when I've already spent several days failing to automate the process?

The pipeline will spin up the following resources in Azure:

- Resource Groups
- vNET
  - Subnet
- Azure Container Registry
- Log Analytics Workspace
- AKS Cluster, inc scale set and role assignments for acr
