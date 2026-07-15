#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly VERSION="2.0.0"
readonly INSTALLER_URL="https://get.acme.sh"

GREEN=""
YELLOW=""
RED=""
RESET=""
if [[ -t 1 ]]; then
    GREEN=$'\033[32;1m'
    YELLOW=$'\033[33;1m'
    RED=$'\033[31m'
    RESET=$'\033[0m'
fi

DOMAINS=()
EMAIL=""
PORT="80"
CERT_DIR=""
SERVER="letsencrypt"
KEY_LENGTH="ec-256"
RELOAD_CMD=""
FORCE=0
ACME_HOME="${ACME_HOME:-${HOME:-/root}/.acme.sh}"
ACME_BIN="${ACME_HOME}/acme.sh"
PRIMARY_DOMAIN=""

green() { printf '%s%s%s\n' "$GREEN" "$*" "$RESET"; }
yellow() { printf '%s%s%s\n' "$YELLOW" "$*" "$RESET" >&2; }
red() { printf '%s%s%s\n' "$RED" "$*" "$RESET" >&2; }
die() { red "错误：$*"; exit 1; }

usage() {
    cat <<'EOF'
Acme.sh 域名证书一键申请脚本

用法：sudo bash acme1key.sh [选项]

  -d, --domain DOMAIN       证书域名，可重复指定以申请 SAN 证书
  -e, --email EMAIL         acme.sh 首次安装时使用的注册邮箱
  -p, --port PORT           standalone 本地监听端口（默认：80）
  -o, --output DIR          证书目录（默认：/root/cert/主域名）
      --server SERVER       ACME 服务（默认：letsencrypt）
      --key-length TYPE     ec-256、ec-384、2048、3072 或 4096
      --reloadcmd COMMAND   签发或续期成功后执行的服务重载命令
      --force               强制重新签发
  -h, --help                显示帮助
  -v, --version             显示版本

不带参数运行时会交互式询问域名和邮箱。
EOF
}

require_value() {
    [[ -n ${2:-} ]] || die "选项 $1 缺少参数"
}

parse_args() {
    while (($#)); do
        case $1 in
            -d|--domain)
                require_value "$1" "${2:-}"
                DOMAINS+=("$2")
                shift 2
                ;;
            -e|--email)
                require_value "$1" "${2:-}"
                EMAIL=$2
                shift 2
                ;;
            -p|--port)
                require_value "$1" "${2:-}"
                PORT=$2
                shift 2
                ;;
            -o|--output)
                require_value "$1" "${2:-}"
                CERT_DIR=$2
                shift 2
                ;;
            --server)
                require_value "$1" "${2:-}"
                SERVER=$2
                shift 2
                ;;
            --key-length)
                require_value "$1" "${2:-}"
                KEY_LENGTH=$2
                shift 2
                ;;
            --reloadcmd)
                require_value "$1" "${2:-}"
                RELOAD_CMD=$2
                shift 2
                ;;
            --force)
                FORCE=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                printf '%s\n' "$VERSION"
                exit 0
                ;;
            *)
                die "未知选项：$1（使用 --help 查看帮助）"
                ;;
        esac
    done
}

trim() {
    local value=$1
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

valid_domain() {
    local domain=$1
    ((${#domain} <= 253)) &&
        [[ $domain == *.* ]] &&
        [[ ! $domain =~ ^[0-9.]+$ ]] &&
        [[ $domain =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

valid_email() {
    [[ $1 =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

valid_port() {
    [[ $1 =~ ^[0-9]{1,5}$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535))
}

collect_input() {
    local input
    local -a entered_domains

    if ((${#DOMAINS[@]} == 0)); then
        [[ -t 0 ]] || die "非交互模式请使用 -d 指定域名"
        read -r -p "请输入域名（多个域名用逗号分隔）：" input || die "未读取到域名"
        IFS=',' read -r -a entered_domains <<< "$input"
        DOMAINS+=("${entered_domains[@]}")
    fi

    if [[ ! -x $ACME_BIN && -z $EMAIL ]]; then
        [[ -t 0 ]] || die "首次安装 acme.sh 时请使用 -e 指定邮箱"
        read -r -p "请输入注册邮箱：" EMAIL || die "未读取到邮箱"
    fi
}

normalize_config() {
    local index domain

    ((${#DOMAINS[@]})) || die "至少需要一个域名"
    for index in "${!DOMAINS[@]}"; do
        domain=$(trim "${DOMAINS[$index]}")
        domain=${domain%.}
        domain=${domain,,}
        valid_domain "$domain" || die "无效域名：${DOMAINS[$index]}（standalone 模式不支持通配符）"
        DOMAINS[$index]=$domain
    done

    PRIMARY_DOMAIN=${DOMAINS[0]}
    valid_port "$PORT" || die "端口必须是 1-65535 之间的整数"
    if [[ ! -x $ACME_BIN ]]; then
        valid_email "$EMAIL" || die "首次安装 acme.sh 时需要有效邮箱"
    elif [[ -n $EMAIL ]]; then
        valid_email "$EMAIL" || die "邮箱格式无效：$EMAIL"
    fi
    case $KEY_LENGTH in
        ec-256|ec-384|2048|3072|4096) ;;
        *) die "不支持的密钥类型：$KEY_LENGTH" ;;
    esac
    [[ -n $SERVER ]] || die "ACME 服务不能为空"

    if [[ -z $CERT_DIR ]]; then
        CERT_DIR="/root/cert/${PRIMARY_DOMAIN}"
    fi
    [[ $CERT_DIR == /* && $CERT_DIR != / ]] || die "证书目录必须是非根目录的绝对路径"
}

install_dependencies() {
    local manager cron_package cron_service
    local -a packages=()

    if command -v apt-get >/dev/null 2>&1; then
        manager=apt
        cron_package=cron
        cron_service=cron
    elif command -v dnf >/dev/null 2>&1; then
        manager=dnf
        cron_package=cronie
        cron_service=crond
    elif command -v yum >/dev/null 2>&1; then
        manager=yum
        cron_package=cronie
        cron_service=crond
    else
        die "仅支持使用 apt、dnf 或 yum 的 Linux 发行版"
    fi

    command -v curl >/dev/null 2>&1 || packages+=(curl)
    command -v openssl >/dev/null 2>&1 || packages+=(openssl)
    command -v socat >/dev/null 2>&1 || packages+=(socat)
    command -v crontab >/dev/null 2>&1 || packages+=("$cron_package")

    if ((${#packages[@]})); then
        green "正在安装缺少的依赖：${packages[*]}"
        case $manager in
            apt)
                apt-get update || die "软件包索引更新失败"
                DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" || die "依赖安装失败"
                ;;
            dnf)
                dnf -y install "${packages[@]}" || die "依赖安装失败"
                ;;
            yum)
                yum -y install "${packages[@]}" || die "依赖安装失败"
                ;;
        esac
    fi

    local command_name
    for command_name in curl openssl socat crontab; do
        command -v "$command_name" >/dev/null 2>&1 || die "缺少命令：$command_name"
    done

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable --now "$cron_service" >/dev/null 2>&1 || yellow "警告：无法启动 $cron_service，请手动启动以保证自动续期"
    elif command -v service >/dev/null 2>&1; then
        service "$cron_service" start >/dev/null 2>&1 || yellow "警告：无法启动 $cron_service，请手动启动以保证自动续期"
    else
        yellow "警告：未找到服务管理器，请确认 cron 服务正在运行"
    fi
}

check_port() {
    if command -v ss >/dev/null 2>&1; then
        if [[ -n $(ss -H -ltn "sport = :${PORT}" 2>/dev/null) ]]; then
            die "本机端口 $PORT 已被占用，请先停止占用服务"
        fi
    elif command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        die "本机端口 $PORT 已被占用，请先停止占用服务"
    fi
}

ensure_acme() {
    local installer

    if [[ ! -x $ACME_BIN ]]; then
        green "正在安装 acme.sh..."
        installer=$(mktemp) || die "无法创建临时文件"
        if ! curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 "$INSTALLER_URL" -o "$installer"; then
            rm -f "$installer"
            die "acme.sh 安装脚本下载失败"
        fi
        if ! sh "$installer" "email=$EMAIL"; then
            rm -f "$installer"
            die "acme.sh 安装失败"
        fi
        rm -f "$installer"
        [[ -x $ACME_BIN ]] || die "安装完成但未找到 $ACME_BIN"
    else
        green "检测到已安装的 acme.sh"
    fi

    "$ACME_BIN" --upgrade --auto-upgrade >/dev/null 2>&1 || yellow "警告：acme.sh 升级失败，将继续使用当前版本"
    "$ACME_BIN" --set-default-ca --server "$SERVER" || die "无法设置 ACME 服务：$SERVER"
}

issue_certificate() {
    local domain
    local -a issue_args=(--issue --standalone --server "$SERVER" --keylength "$KEY_LENGTH" --httpport "$PORT")

    for domain in "${DOMAINS[@]}"; do
        issue_args+=(-d "$domain")
    done
    if ((FORCE)); then
        issue_args+=(--force)
    fi

    green "正在为 ${DOMAINS[*]} 申请证书..."
    "$ACME_BIN" "${issue_args[@]}" || die "证书申请失败；已保留 acme.sh 日志和状态以便排查"
}

install_certificate() {
    local ca_file cert_file key_file fullchain_file
    local -a install_args

    mkdir -p "$CERT_DIR" || die "无法创建证书目录：$CERT_DIR"
    chmod 700 "$CERT_DIR" || die "无法设置证书目录权限"

    ca_file="${CERT_DIR}/ca.pem"
    cert_file="${CERT_DIR}/cert.pem"
    key_file="${CERT_DIR}/key.pem"
    fullchain_file="${CERT_DIR}/fullchain.pem"
    install_args=(--install-cert -d "$PRIMARY_DOMAIN" --ca-file "$ca_file" --cert-file "$cert_file" --key-file "$key_file" --fullchain-file "$fullchain_file")

    if [[ $KEY_LENGTH == ec-* ]]; then
        install_args+=(--ecc)
    fi
    if [[ -n $RELOAD_CMD ]]; then
        install_args+=(--reloadcmd "$RELOAD_CMD")
    fi

    "$ACME_BIN" "${install_args[@]}" || die "证书复制到 $CERT_DIR 失败"
    chmod 600 "$key_file" || die "无法设置私钥权限"
    chmod 644 "$ca_file" "$cert_file" "$fullchain_file" || die "无法设置证书权限"

    green "证书申请并安装成功："
    printf '  证书链：%s\n  私钥：%s\n' "$fullchain_file" "$key_file"
    [[ -n $RELOAD_CMD ]] || yellow "提示：可用 --reloadcmd 配置续期后的服务重载命令"
}

main() {
    parse_args "$@"
    ((EUID == 0)) || die "standalone 模式及默认输出目录需要 root 权限"
    collect_input
    normalize_config
    install_dependencies
    check_port
    ensure_acme
    issue_certificate
    install_certificate
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
