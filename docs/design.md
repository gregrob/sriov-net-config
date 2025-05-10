# Design

## Project Structure

```
.gitignore
sriov-net-config.sh
config/
    sriov-net.config.example
docs/
    images/
        sriov-net-config.png
lib/
    config_parser.sh
    setup_pf.sh
    setup_vf.sh
utils/
    common.sh
```

### Key Files

- **`sriov-net-config.sh`**: The main script to configure SR-IOV devices.
- **`config/sriov-net.config.example`**: An example configuration file that demonstrates the format and usage. Customise it for your system and rename it to `sriov-net.config`.
- **`lib/`**: Contains helper scripts for parsing configurations and setting up PFs and VFs.
  - `config_parser.sh`: Parses configuration files.
  - `setup_pf.sh`: Handles PF configuration.
  - `setup_vf.sh`: Handles VF configuration.
- **`utils/common.sh`**: Utility functions for logging, error handling, and validation.

## Logging

The script provides logging at different levels:

- **INFO**: General information about the configuration process.
- **WARN**: Warnings about potential issues.
- **ERROR**: Critical errors that stop the script.
- **DEBUG**: Detailed debug information (enabled with `--verbose`).
