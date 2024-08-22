# Acme.sh 域名证书一键申请脚本

[简体中文](https://github.com/aquasofts/acme1key/blob/master/README.md) | [English](https://github.com/aquasofts/acme1key/blob/master/README_EN.md)

此脚本可以帮助你使用acme.sh脚本申请域名的ssl证书

本页fork版对比原脚本基本完全重构

使用端口方式申请脚本

感谢 [x-ui](https://github.com/FranzKafkaYu/x-ui/) 项目中的acme相关代码

如果此脚本对您有帮助，不妨点一个star支持一下，让更多人受到帮助

## 使用方法

```shell
wget -N https://raw.githubusercontent.com/aquasofts/acme1key/master/acme1key.sh && chmod -R 777 acme1key.sh && bash acme1key.sh
```

若您的机器位于中国内地，可使用以下脚本

```shell
wget -N https://gitee.com/aquasoft/acme1key/raw/master/acme1key.sh && chmod -R 777 acme1key.sh && bash acme1key.sh
```

实验性：

```shell
wget -N https://gitee.com/aquasoft/acme1key/raw/master/test/acme1key.sh && chmod -R 777 acme1key.sh && bash acme1key.sh
```

实验性脚本说明：

由 ChatGPT 4o 为我的垃圾代码进行优化，但未经测试，优化内容请参考 [ChatGPT 4o](https://github.com/aquasofts/acme1key/blob/master/test/GPT.md)