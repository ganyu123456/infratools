#!/usr/bin/env bash
# Docker & Docker Compose offline installer
set -euo pipefail

ARCH="${1:-amd64}"
BASE_DIR="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PACKAGES_DIR="${BASE_DIR}/packages/docker"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERR ]${NC}  $*" >&2; }

# -------------------------------------------------------
# 检测是否已安装
# -------------------------------------------------------

is_docker_installed() {
    command -v docker &>/dev/null && docker --version &>/dev/null
}

is_compose_installed() {
    docker compose version &>/dev/null 2>&1 || \
    command -v docker-compose &>/dev/null
}

# -------------------------------------------------------
# 安装 Docker
# -------------------------------------------------------

install_docker() {
    local pkg
    pkg=$(find "${PACKAGES_DIR}" -maxdepth 1 -name "docker-*.tgz" | sort -V | tail -1)

    if [[ -z "${pkg}" ]]; then
        log_error "未找到 Docker 安装包，期望路径: ${PACKAGES_DIR}/docker-*.tgz"
        exit 1
    fi

    log_info "安装包: $(basename "${pkg}")"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '${tmp_dir}'" EXIT

    tar -xzf "${pkg}" -C "${tmp_dir}"

    local bin_dir
    bin_dir=$(find "${tmp_dir}" -maxdepth 2 -name "docker" -type f | head -1 | xargs -r dirname)

    if [[ -z "${bin_dir}" ]]; then
        log_error "解压失败：未找到 Docker 可执行文件"
        exit 1
    fi

    cp -f "${bin_dir}"/* /usr/local/bin/
    chmod +x /usr/local/bin/docker*

    _setup_containerd_service
    _setup_docker_service

    log_ok "Docker 安装完成: $(docker --version)"
}

# -------------------------------------------------------
# 安装 Docker Compose (作为 Docker CLI 插件)
# -------------------------------------------------------

install_compose() {
    local bin
    bin=$(find "${PACKAGES_DIR}" -maxdepth 1 -name "docker-compose" -type f | head -1)

    if [[ -z "${bin}" ]]; then
        log_error "未找到 Docker Compose 安装包，期望路径: ${PACKAGES_DIR}/docker-compose"
        exit 1
    fi

    mkdir -p /usr/local/lib/docker/cli-plugins
    cp -f "${bin}" /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    log_ok "Docker Compose 安装完成: $(docker compose version)"
}

# -------------------------------------------------------
# 配置 containerd systemd 服务
# -------------------------------------------------------

_setup_containerd_service() {
    if ! command -v systemctl &>/dev/null; then
        return
    fi

    if systemctl is-active --quiet containerd 2>/dev/null; then
        log_info "containerd 服务已在运行，跳过配置"
        return
    fi

    cat > /etc/systemd/system/containerd.service <<'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=1048576
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable containerd.service
    systemctl start containerd.service
    log_ok "containerd 服务已启动"
}

# -------------------------------------------------------
# 配置 Docker systemd 服务
# -------------------------------------------------------

_setup_docker_service() {
    # 创建 docker 用户组
    if ! getent group docker &>/dev/null; then
        groupadd docker
        log_info "已创建 docker 用户组"
    fi

    if ! command -v systemctl &>/dev/null; then
        log_warn "未检测到 systemd，请手动启动 dockerd"
        return
    fi

    cat > /etc/systemd/system/docker.service <<'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service containerd.service time-set.target
Wants=network-online.target
Requires=docker.socket containerd.service

[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/docker.socket <<'EOF'
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

    systemctl daemon-reload
    systemctl enable docker.socket docker.service
    systemctl start docker.socket docker.service
    log_ok "Docker 服务已启动"
}

# -------------------------------------------------------
# 主流程
# -------------------------------------------------------

main() {
    local docker_skip=false
    local compose_skip=false

    if is_docker_installed; then
        log_warn "Docker 已安装 ($(docker --version))，跳过"
        docker_skip=true
    fi

    if is_compose_installed; then
        log_warn "Docker Compose 已安装 ($(docker compose version 2>/dev/null || docker-compose --version))，跳过"
        compose_skip=true
    fi

    if [[ "${docker_skip}" == "true" && "${compose_skip}" == "true" ]]; then
        log_ok "Docker 和 Docker Compose 均已安装，无需重新安装"
        return 0
    fi

    [[ "${docker_skip}" == "false" ]] && install_docker
    [[ "${compose_skip}" == "false" ]] && install_compose
}

main
