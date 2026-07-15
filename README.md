# Acme.sh 域名证书一键申请脚本

[简体中文](https://github.com/aquasofts/acme1key/blob/master/README.md) | [English](https://github.com/aquasofts/acme1key/blob/master/README_EN.md)

此脚本可以帮助你使用 [acme.sh](https://github.com/acmesh-official/acme.sh) 的 standalone 模式申请 SSL 证书。

本版在原脚本基础上重写，支持 apt/dnf/yum、多个 SAN 域名、RSA/ECC 密钥、自定义输出目录及续期重载命令。

感谢 [x-ui](https://github.com/FranzKafkaYu/x-ui/) 项目中的 acme 相关代码。如果此脚本对您有帮助，不妨点一个 star 支持一下。

## 使用方法

交互式运行：

```shell
wget -O acme1key.sh https://raw.githubusercontent.com/aquasofts/acme1key/master/acme1key.sh && chmod +x acme1key.sh && sudo ./acme1key.sh
```

也可以直接传参（重复 `-d` 可加入多个域名）：

```shell
sudo ./acme1key.sh -d example.com -d www.example.com -e admin@example.com --reloadcmd "systemctl reload nginx"
```

证书默认保存到 `/root/cert/主域名/`。公网 80 端口必须可访问且本机监听端口未被占用；自定义端口仅适用于已将公网 80 端口转发到该端口的环境。完整参数见 `./acme1key.sh --help`，旧代码保存在 [`old`](https://github.com/aquasofts/acme1key/tree/master/old) 目录。
