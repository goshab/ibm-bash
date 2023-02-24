# API Gateway configuration

## Support

Successfully tested setup:

- DataPower 2018.4.1.13, 3-node cluster deployments.

## Features

- This set of scripts automates API Connect Gateway v6 configuration on DataPower.
- The DataPower GWD and DataPower GW configurations are based on the same crypto keys (the certificate can be CA-signed or self-signed).
- Supports shared ETH interface for management and data traffic.
- Supports two CA certificates in the chain.
- Supports three DataPower gateways in the Gateway Service.

## Usage

- Make sure curl CLI is in the PATH.
- Enable XML Management Interface on all DataPower gateways.
- Enable REST Management Interface on all DataPower gateways.
- Clone this repository to you local folder.
- Copy over the certificates and private key to the script folder.
- Duplicate the [script](deploy-dp.sh) and fill out the configuration section.
- Run the script.

## Future features and know limitations

- None.
