# API Connect OVA form factor deployment

## Features

- This set of scripts is used to automate generation of API Connect ISO files for VMWare deployment.
- Supports standalone API Connect deployments.

## Support

Successfully tested setup:

- API Connect 10.0.5.1, standalone.

## Usage

- The `apicup` CLI is located in the same folder with the scripts.
- Duplicate the provided [project configuration template](00-project-template.conf) and fill it out.
- Initialize a new API Connect project by running the provided [script](01-init-apic.sh) and passing the configuration file as an argument.
- Run the remaining scripts passing the configuration file as an argument.

## Future features

- Add support for Management backup configuration.
- Add support for Portal backup configuration.
- Add support for cluster deployments.
- Add support for 2HADR configuration.
- Add apic CLI version verification.
