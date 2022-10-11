# AVD Hostpool Pipeline

---

Contents

- [AVD Hostpool Pipeline](#avd-hostpool-pipeline)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Running The Pipeline](#running-the-pipeline)

## Introduction

Running this pipeline will create the following resources:

- Resource Group
- AVD Hostpool
- Desktop Application Group (DAG)
- Required number of Session Hosts
- NICs for the created Session Hosts
- Extensions to join Session Hosts to domain and to the Hostpool
- A Log analytics workspace
- A Backup Recovery Vault
- Diagnostic settings to point the Host Pool to a created Log Analytics Workspace
- Backups to the created Backup recovery vault
- Will set up mapping for the application group to a chosen AD/AAD group

The pipeline will link the DAG to the AVD-Workspace that is created as part of the pipeline.

---

## Prerequisites

There are a few things to be mindful of **before** running the pipeline, so check through the below before getting carried away.

- You need to have the following resources in Azure

  - VNET/Subnet and any required route table additions

  - AVD Image

    - ***Please make sure you have set the right execution policy (unrestricted) before capturing the image. You can do this by running the following command before capturing the image.***

    ``` Powershell
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -scope LocalMachine -Force
    ```

- You will also need to have the following ready:

  - An on-prem OU for AVD VM to live in
  
  - Relevant Group Policies linked to said OU

  - An AD Group to associate with the AVD pool


- ***Important*** - If you wish to expand, or reduce an existing hostpool, simply amend the relative .tf file and increase/decrease the vm_count variable as required.

  - If you wish to update the image used in a pool, simply update the source_image_id variable with the id for your new imageversion and run the pipeline. 

---

## Running The Pipeline

In order to run the pipeline correctly, there are several steps:

1. ### Creating The Terraform File

    The first thing to do is to create a new .tf file and copy in the contents of "SHP-AVD-POOL.template"

     You will need to create this copied file within the avd directory. Please rename the file to the name of your new host pool.

    Lastly, make sure to change the module name in your new file to the same name as your host pool.

2. ### Variables

    Within the new .tf file you have created, you will need to change each of the variables to reflect the new host pool you are creating.

    You can find a full list of virtual machine sizes for vm_size [here](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-general).

    Here is a quick cheat sheet on the variables required and what they mean:

    #### Mandatory Variables

    These variables need to be included in the file and should be specific to each pool.

    | Variable      | Description |
    |:------------- |:-------------|
    |avd_purpose    |This should be a short, ideally 3-5 letter abbreviation to show the purpose of the AVD (e.g. INF). This will be used for the vm names, as well as the host pool name.
    |desktop_name | This name will be displayed when a user connects to the pool (i.e "uS General Desktop) |
    |user_group| This is the **object ID** for whatever AD group you would like to assign to access the AVD pool. Note - if this is not included it defaults to an Infra only group.|
    |friendly_name  |A friendly name for the host pool and app group|
    |description    |Something descriptive for the host pool and app group. "Created by Terraform" will be appended automagically|
    |subnet_name      |The name of the subnet the AVD will live on|
    |vm_size        |Required VM size for the AVDs|
    |vm_count     |How many AVDs to provision into the pool|
    |source_image_id|Resource ID of the image to be used. You can get this from the properties blade on the image in Azure - You need the full resource ID|
    |ou_path        |Full path of the OU for AVDs to live in|

    #### Static Variables

    These variables need to be included in every file and should **never** be changed.

    | Variable      | Description |
    |:------------- |:-------------|
    |workspace_id| This passes through the workspace that is created as a part of this pipeline|
    |loganalytics_id|This passes through the log analytics workspace for AVD monitoring|
    |backups_rg|This passes through the resource group for backups|
    |vault_name| This passes through the recovery service vault name for backups|
    |policy_id|This passes through the backup policy ID for backups|
    |local_password |This is called during the pipeline to set the local machine password|
    |domain_password|This is called during the pipaline to join the machine to the domain|

3. ### Provisioning

    Once you have finished amending the .tf file for your new host pool - you are ready to commit!

    As you cannot commit into the main branch, please ensure you are deploying via a pull request that can be signed off by another member of the infrastructure team.

---
