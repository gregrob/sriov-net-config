# SR-IOV Network Configurator

<img src='docs/images/sriov-net-config.png' width='200'>

The **SR-IOV Network Configurator** is a Bash-based tool designed to simplify the configuration of SR-IOV (Single Root I/O Virtualization) network devices. It provides a flexible and automated way to configure Physical Functions (PFs) and Virtual Functions (VFs) on SR-IOV-enabled network interfaces.

This tool was initially developed to efficiently manage network Virtual Functions (VFs) on my Minisforum MS-01 Proxmox cluster.

## Features

- **Global and Host-Specific Configuration**: Supports both global settings and host-specific overrides for flexible deployment.
- **VF Configuration**: Configure VLANs, activate/deactivate VFs, rename VF interfaces, and bind them to specific drivers.
- **PF Configuration**: Create and manage VFs for PFs, assign MAC addresses, and handle SR-IOV autoprobe settings.
- **Dry-Run Mode**: Simulate changes without applying them to the system.
- **Detailed Configuration Reports**: Generate detailed breakdowns of parsed configurations for diagnostics.

## Getting Started

### Prerequisites

- A Linux system with SR-IOV-enabled network interfaces.
- Bash shell (version 4.0 or higher).
- Root privileges to apply network configurations.

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/gregrob/sriov-net-config.git
   cd sriov-net-config
   ```

2. Copy the example configuration file to create your own:
   ```bash
   cp config/sriov-net.config.example config/sriov-net.config
   ```

3. Edit `config/sriov-net.config` to define your SR-IOV configuration.

### Usage

Run the script with the desired options:

```bash
sriov-net-config.sh [options]
```

#### Options

- `--config <file>`: Specify a custom configuration file (default: `config/sriov-net.config`).
- `--vf <dev> <vf>`: Configure a specific VF (e.g., `--vf enlan3 21`).
- `--host <hostname>`: Override the hostname for host-specific configurations.
- `--verbose`: Enable debug output.
- `--dry-run`: Simulate changes without applying them.
- `--config-report`: Show a detailed configuration report.
- `--help`: Display usage information.

### Example

To configure all PFs and VFs based on the default configuration file:

```bash
sudo sriov-net-config.sh
```

To simulate the configuration without making changes:

```bash
sudo sriov-net-config.sh --dry-run
```

To configure a specific VF:

```bash
sudo sriov-net-config.sh --vf enlan3 2
```

## Configuration File Format

The configuration file supports two sections: `all:` for global settings and `<hostname>:` for host-specific overrides.

When a configuration is specified in both the `all:` section and the `<hostname>:` section, the settings in the `<hostname>:` section will take precedence.

### Physical Function (PF) Configuration

#### Format
```
pf <dev> <num_vfs> <mac_prefix> [# comment]
```

- **`<dev>`**: The name of the Physical Function (PF) network device (e.g. `enlan3`).
- **`<num_vfs>`**: The number of Virtual Functions (VFs) to create on the specified PF.
- **`<mac_prefix>`**: The MAC address prefix to assign to the VFs. The last octets will be incremented automatically for each VF.
- **`[# comment]`**: Optional comment to describe the configuration or its purpose.

<br>

> **Note:** Ensure that the MAC address assignment uses a valid OUI for the network adapter.  
> For the MS-01, which features an Intel 700 series adapter, the OUI `58:47:CA` is recommended for configuring MAC addresses.

#### Example
```
pf enlan3 32 58:47:ca:00:00:00 # Configure 32 VFs on enlan3
```

In this example:
- `enlan3` is the PF device.
- `32` VFs will be created.
- The MAC addresses for the VFs will start with the prefix `58:47:ca` and increment from `00:00:00`.

### Virtual Function (VF) Configuration

#### Format:
```
vf <dev> <vf_idx> <vlan> <activate> <rename> <driver> [# comment]
```

- **`<dev>`**: The name of the Virtual Function's (VF) parent Physical Function (PF) network device (e.g. `enlan3`).
- **`<vf_idx>`**: The index of the VF to configure (e.g., `1` for VF 1).
- **`<vlan>`**: The VLAN ID to assign to the VF (e.g., `0` for no VLAN or `100` for VLAN 100).
- **`<activate>`**: A boolean value (`true` or `false`) to activate or deactivate the VF.
- **`<rename>`**: A boolean value (`true` or `false`) to rename the VF interface for easier identification.
- **`<driver>`**: The driver to bind the VF to (e.g., `iavf` for Intel VFs).
- **`[# comment]`**: Optional comment to describe the configuration or its purpose.

#### Example
```
vf enlan3 1 0 true true iavf # Configure VF 1 on enlan3
```

In this example:
- `enlan3` is the parent PF device.
- `1` is the VF index.
- `0` indicates no VLAN is assigned.
- The VF is activated (`true`) and renamed (`true`).
- The VF is bound to the `iavf` driver.
- The comment explains the purpose of the configuration.

## Further Reading

For design details, see the [Design Document](docs/design.md).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
