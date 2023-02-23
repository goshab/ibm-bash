# API Gateway configuration

## Support

Successfully tested on:

- DataPower 10.0.5.2, standalone and 3-node cluster.

## Features

- This set of scripts automates API Connect Gateway v6 configuration on DataPower.
- The DataPower GWD and DataPower GW configurations are based on the same crypto keys (the cert can be CA-signed or self-signed).
- The Gateway setup supports separete ETH interfaces for management and data traffic.
- Support none to multiple number of CA certificates in the chain.
- Support up to three DataPower gateways in the Gateway Service.

## Usage

- Make sure curl CLI is in the PATH.
- Make sure jq CLI is in the PATH.
- Enable XML Management Interface on all DataPower gateways.
- Enable REST Management Interface on all DataPower gateways.
- Clone this repository to you local folder.
- Duplicate the [provided template](00-project-template.conf) and fill it out.
- Initialize a new Gateway Service project by running [the provided script](01-init-dp.sh).
- Copy over the certificates and private key to the $PROJECT_DIR/$KEYS_DIR folder.
- Execute the project by running the [deployment script](08-deploy-dp.sh) and passing the configuration file as an argument.

## Future features and know limitations

- Add support for TLSv13.
- Add certificate validation step.
- Separate GWD and GW crypto keys.
- Move common utils to external location.
- Add NTP configuration (check DP form factor).
- Add support for dynamic number for gateways (currently supports upto to 3 DP gateways).
