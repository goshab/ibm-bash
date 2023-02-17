# API Connect OVA form factor deployment

## Introduction

This set of scripts is used to automate API Connect deployment on VMWare.
The Gateway is setup with a shared ETH for management and data traffic.
The Gateway GWD and GW configuration is based on the same crypto keys.

## Support

Successfully tested on:

- API Connect 10.0.5.2, standalone.
- DataPower 10.0.5.2, standalone and 3-node cluster.

## API Connect future features

- Support Management and Portal backup configuration.

## DataPower future features

- Enable DP Statistics.
- Add NTP configuration (check DP form factor).
- Add support for TLSv13.
- Add standard logging functions.
- Add SOMA_URL and ROMA_RUL dynamic calculation based on number of gateways.
- Add Throttler configuration.
- Refactor out SOMA functions from 08-deploy-dp.sh into an external file.
