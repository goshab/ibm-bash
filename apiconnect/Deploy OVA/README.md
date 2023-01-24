# API Connect OVA form factor deployment

## Introduction

This set of scripts is used to automate API Connect v10 deployment on VMWare.
The Gateway is setup with a shared ETH for management and data traffic.
The Gateway GWD and GW configuration is based on the same crypto keys.

## Support

Successfully tested on:

1. API Connect 10.0.5.2, standalone.

## Future features

1. Pass env.conf file as an external parameter.
2. Refactor out SOMA and ROMA functions from 08-deploy-dp.sh into an external file.
3. Refactor out the 08-deploy-dp.sh custom configuration section to env.conf file.
4. Support multiple ETH interfaces for separate management and data traffic (certs).
5. Support Management and Portal backup configuration.
6. Enable DP Statistics
