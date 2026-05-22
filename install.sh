#!/usr/bin/env bash
# infratools 离线安装主入口
# 用法: sudo bash install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERR ]${NC}  $*" >&2; }
log_step()  { echo -e "\n${BOLD}${BLUE}──────── $* ────────${NC}"; }
log_banner() {
    echo -e "${BOLD}"
    echo "  ██╗███╗   ██╗███████╗██████╗  █████╗ ████████╗ ██████╗  ██████╗ ██╗     ███████╗"
    echo "  ██║████╗  ██║██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝"
    echo "  ██║██╔██╗ ██║█████╗  ██████╔╝███████║   ██║   ██║   ██║██║   ██║██║     ███████╗"
    echo "  ██║██║╚██╗██║██╔══╝  ██╔══██╗██╔══██║   ██║   ██║   ██║██║   ██║██║     ╚════██║"
    echo "  ██║██║ ╚████║██║     ██║  ██║██║  ██║   ██║   ╚██████╔╝╚██████╔╝███████╗███████║"
    echo "  ╚═╝╚═╝  ╚═══╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝"
    echo -e "${NC}"
}

# -------------------------------------------------------
# 检查 root 权限
# -------------------------------------------------------

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 权限运行: sudo bash install.sh"
        exit 1
    fi
}

# -------------------------------------------------------
# 检测系统架构
# -------------------------------------------------------

detect_arch() {
    local machine
    machine=$(uname -m)
    case "${machine}" in
        x86_64)          echo "amd64" ;;
        aarch64 | arm64) echo "arm64" ;;
        *)
            log_error "不支持的系统架构: ${machine}（仅支持 amd64 / arm64）"
            exit 1
            ;;
    esac
}

# -------------------------------------------------------
# 读取版本信息
# -------------------------------------------------------

load_versions() {
    local ver_file="${SCRIPT_DIR}/versions.env"
    if [[ -f "${ver_file}" ]]; then
        # shellcheck disable=SC1090
        source "${ver_file}"
    fi
    DOCKER_VERSION="${DOCKER_VERSION:-unknown}"
    COMPOSE_VERSION="${COMPOSE_VERSION:-unknown}"
}

# -------------------------------------------------------
# 主流程
# -------------------------------------------------------

main() {
    log_banner
    check_root

    ARCH=$(detect_arch)
    load_versions

    echo -e "  ${BOLD}系统架构${NC}: ${ARCH}"
    echo -e "  ${BOLD}Docker   ${NC}: ${DOCKER_VERSION}"
    echo -e "  ${BOLD}Compose  ${NC}: ${COMPOSE_VERSION}"
    echo ""

    # ── Docker & Docker Compose ──────────────────────────
    log_step "Docker & Docker Compose"
    bash "${SCRIPT_DIR}/docker/install.sh" "${ARCH}" "${SCRIPT_DIR}"

    # ── 汇总 ────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}${GREEN}============================================${NC}"
    echo -e "${BOLD}${GREEN}  安装完成！${NC}"
    echo -e "${BOLD}${GREEN}============================================${NC}"
    echo ""
    log_info "Docker         : $(docker --version 2>/dev/null || echo '获取失败')"
    log_info "Docker Compose : $(docker compose version 2>/dev/null || echo '获取失败')"
    echo ""
    log_info "如需将当前用户加入 docker 组，请执行:"
    echo -e "  ${YELLOW}sudo usermod -aG docker \$USER && newgrp docker${NC}"
    echo ""
}

main "$@"
