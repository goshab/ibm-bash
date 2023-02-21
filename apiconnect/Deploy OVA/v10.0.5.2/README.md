# API Connect OVA form factor deployment

## Support

Successfully tested on:

- API Connect 10.0.5.2, standalone.
- DataPower 10.0.5.2, standalone and 3-node cluster.

## API Connect

This set of scripts is used to automate API Connect deployment on VMWare.

### API Connect prerequisites

- apicup CLI is located in the root folder.
- Fill out the configuration file and pass it as a CLI argument to the API Connect scripts. Use the [provided template](00-project-template.conf).

### API Connect future features

- Add support for Management backup configuration.
- Add support for Portal backup configuration.

## DataPower

- This set of scripts automates API Connect Gateway v6 configuration on DataPower.
- The Gateway setup supports separete ETH interfaces for management and data traffic.
- The DataPower GWD and DataPower GW configurations are based on the same crypto keys (the cert can be CA-signed or self-signed).

### DataPower prerequisites

- XML Management Interface is enabled on all DataPower gateways.
- REST Management Interface is enabled on all DataPower gateways.
- Certificates and private key need to be located in the $PROJECT_DIR/$KEYS_DIR folder.
- Fill out the configuration file and pass it as a CLI argument to the [DataPower script](08-deploy-dp.sh). Use the [provided template](00-project-template.conf).

### DataPower future features and know limitations

- Add support for TLSv13.
- Add support for dynamic list of CA certs.
- Add NTP configuration (check DP form factor).
- Add certificate verify step after Cert obj create.
- Add support for dynamic number for gateways. Currently supports upto to 3 DP gateways.
