# API Connect OVA form factor deployment

## Introduction

This set of scripts is used to automate API Connect deployment on VMWare.
The Gateway setup supports separete ETH interfaces for management and data traffic.
The DataPower GWD and DataPower GW configurations are based on the same crypto keys (the cert can be CA-signed or self-signed).

## DataPower prerequisites

- XML Management Interface is enabled on all DataPower gateways.
- REST Management Interface is enabled on all DataPower gateways.
- Same credentials are used for all DataPower gateways.
- Certificates and private key are located in the PROJECT/keys folder.
- Fill out the configuration file and pass it as a CLI argument to the [script](08-deploy-dp.sh). Use the [provided template](00-project-template.conf).

## Support

Successfully tested on:

- API Connect 10.0.5.2, standalone.
- DataPower 10.0.5.2, standalone and 3-node cluster.

## API Connect future features

- Support Management and Portal backup configuration.

## DataPower future features and know limitations

- Add support for TLSv13.
- Add NTP configuration (check DP form factor).
- Currently supports upto to 3 DP in cluster. Solution - add SOMA_URL and ROMA_RUL dynamic calculation based on number of gateways.
