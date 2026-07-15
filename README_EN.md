# Acme.sh One-Click Domain Certificate Application Script

[简体中文](https://github.com/aquasofts/acme1key/blob/master/README.md) | [English](https://github.com/aquasofts/acme1key/blob/master/README_EN.md)

This script uses [acme.sh](https://github.com/acmesh-official/acme.sh) standalone mode to issue SSL certificates.

Rewritten from the original script, it supports apt/dnf/yum, multiple SAN domains, RSA/ECC keys, custom output directories, and renewal reload commands.

Special thanks to the [x-ui](https://github.com/FranzKafkaYu/x-ui/) project for its acme-related code. If this script helps you, consider giving it a star.

## Usage

Interactive mode:

```shell
wget -O acme1key.sh https://raw.githubusercontent.com/aquasofts/acme1key/master/acme1key.sh && chmod +x acme1key.sh && sudo ./acme1key.sh
```

Or pass options directly (repeat `-d` for SAN domains):

```shell
sudo ./acme1key.sh -d example.com -d www.example.com -e admin@example.com --reloadcmd "systemctl reload nginx"
```

Certificates are saved to `/root/cert/primary-domain/` by default. Public port 80 must be reachable and the local listening port must be free; a custom port only works when public port 80 is forwarded to it. Run `./acme1key.sh --help` for all options. Previous versions are kept in [`old`](https://github.com/aquasofts/acme1key/tree/master/old).
