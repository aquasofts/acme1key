#!/bin/bash

# 清除环境并修复损坏的依赖项
apt --fix-broken install

# 获取本机 IP 地址
IP=$(curl -s ipget.net)

# 定义颜色输出函数
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

# 检查是否为 root 用户
if [[ $(id -u) != 0 ]]; then
    red "请在 root 用户下运行脚本"
    exit 1
fi

# 系统判别及软件包管理器配置
if [[ -f /etc/redhat-release ]]; then
    release="CentOS"
elif grep -qiE "debian" /etc/issue /proc/version; then
    release="Debian"
elif grep -qiE "ubuntu" /etc/issue /proc/version; then
    release="Ubuntu"
else
    red "不支持的操作系统"
    exit 1
fi

case $release in
    Debian|Ubuntu)
        PACKAGE_UPDATE="apt-get -y update"
        PACKAGE_INSTALL="apt-get -y install"
        PACKAGE_UNINSTALL="apt-get -y autoremove"
        CRON_SERVICE="cron"
        ;;
    CentOS)
        PACKAGE_UPDATE="yum -y update"
        PACKAGE_INSTALL="yum -y install"
        PACKAGE_UNINSTALL="yum -y autoremove"
        CRON_SERVICE="crond"
        ;;
esac

# 安装必要的软件包
$PACKAGE_UPDATE
for pkg in curl wget socat; do
    if ! command -v $pkg &> /dev/null; then
        $PACKAGE_INSTALL $pkg
    fi
done

# 确保 cron 服务已启动并设置为开机启动
if ! systemctl is-active --quiet $CRON_SERVICE; then
    $PACKAGE_INSTALL $CRON_SERVICE
    systemctl start $CRON_SERVICE
    systemctl enable $CRON_SERVICE
fi

# 安装 acme.sh
read -rp "请输入注册邮箱（例：admin@gmail.com，或留空自动生成）：" acmeEmail
if [[ -z $acmeEmail ]]; then
    acmeEmail=$(date +%s%N | md5sum | cut -c 1-32)@gmail.com
fi
curl -s https://get.acme.sh | sh -s email=$acmeEmail
source ~/.bashrc
~/.acme.sh/acme.sh --upgrade --auto-upgrade
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
    green "Acme.sh 证书申请脚本安装成功！"
else
    red "抱歉，Acme.sh 证书申请脚本安装失败"
    yellow "建议如下："
    yellow "1. 检查 VPS 的网络环境"
    yellow "2. 脚本可能跟不上时代，建议截图发布到 GitHub Issues 或 TG 群询问"
    exit 1
fi

# 获取并验证域名
read -rp "请输入你的域名: " domain
green "你输入的域名为: ${domain}, 正在进行域名合法性校验..."
if ~/.acme.sh/acme.sh --list | grep -q "$domain"; then
    red "域名合法性校验失败，当前环境已有对应域名证书，不可重复申请。"
    ~/.acme.sh/acme.sh --list
    exit 1
else
    green "域名合法性校验通过..."
fi

# 获取并验证端口
read -rp "请输入你所希望使用的端口, 如回车将使用默认80端口(此端口需要未被占用): " WebPort
WebPort=${WebPort:-80}
if [[ $WebPort -gt 65535 || $WebPort -lt 1 ]]; then
    yellow "你所选择的端口 $WebPort 为无效值, 将使用默认80端口进行申请"
    WebPort=80
fi
green "将会使用端口 $WebPort 进行证书申请, 请确保端口处于开放状态..."

# 申请证书
~/.acme.sh/acme.sh --issue -d "$domain" --standalone --httpport "$WebPort"
if [[ $? -ne 0 ]]; then
    red "证书申请失败, 原因请参见报错信息"
    rm -rf ~/.acme.sh/"$domain"
    exit 1
else
    green "证书申请成功, 开始安装证书..."
fi

# 安装证书
certPath="/root/cert"
~/.acme.sh/acme.sh --installcert -d "$domain" \
    --ca-file "$certPath/ca.cer" \
    --cert-file "$certPath/$domain.cer" \
    --key-file "$certPath/$domain.key" \
    --fullchain-file "$certPath/fullchain.cer"

if [[ $? -ne 0 ]]; then
    red "证书安装失败，脚本退出"
    rm -rf ~/.acme.sh/"$domain"
    exit 1
else
    green "证书安装成功，开启自动更新..."
fi

~/.acme.sh/acme.sh --upgrade --auto-upgrade
if [[ $? -ne 0 ]]; then
    red "自动更新设置失败，脚本退出"
    exit 1
else
    green "证书已安装且已开启自动更新，具体信息如下："
    ls -lah "$certPath"
    chmod 755 "$certPath"
fi