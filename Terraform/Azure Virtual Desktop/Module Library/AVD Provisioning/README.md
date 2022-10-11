# AVD Provisioning Module

This module is intended to be referenced by the AVD Pipeline.

You will need to change some information in here before it is ready to run, most notably:

- Tags
  - Each resource in this module has a tags block, please add whichever tags you desire

- custom_rdp_properties (line 26)
  - This is currently set to block copy/paste and allow audio redirection

- subnet_id (line 100)
  - Copy the full resource path for your Subnet, up the VNET bit

- settings (line 157 and 159)
  - Enter the domain you wish to join the AVDs to
  - Enter a domain admin username for joining the machines to the domain
