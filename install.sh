#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="${HOME}/.local/opt"
INSTALL_DIR="${INSTALL_ROOT}/yazi"
BIN_DIR="${HOME}/.local/bin"
TARGET_VERSION=""
TMP_DIR=""

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

trap cleanup EXIT

log() {
  printf '[yazi-install] %s\n' "$*" >&2
}

fail() {
  printf '[yazi-install] 错误: %s\n' "$*" >&2
  exit 1
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    fail "缺少 sudo，无法自动安装依赖：$*"
  fi

  sudo "$@"
}

check_system() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    fail "此脚本仅支持 Linux 系统，当前为 $(uname -s)"
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)   printf 'x86_64-unknown-linux-gnu' ;;
    aarch64|arm64)  printf 'aarch64-unknown-linux-gnu' ;;
    i686|i386)      printf 'i686-unknown-linux-gnu' ;;
    riscv64)        printf 'riscv64gc-unknown-linux-gnu' ;;
    sparc64)        printf 'sparc64-unknown-linux-gnu' ;;
    *)              fail "不支持的架构: $(uname -m)" ;;
  esac
}

resolve_version() {
  if [[ -n "${TARGET_VERSION}" ]]; then
    printf '%s\n' "${TARGET_VERSION}"
    return
  fi

  local ver=""
  ver="$(
    curl -fsSL --max-time 10 \
      'https://api.github.com/repos/sxyazi/yazi/releases/latest' 2>/dev/null \
      | grep '"tag_name"' \
      | head -1 \
      | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
  )" || true

  if [[ -z "${ver}" ]]; then
    ver="v26.1.22"
    log "无法从 GitHub API 获取最新版本，使用内置版本: ${ver}"
  fi

  printf '%s\n' "${ver}"
}

ensure_packages() {
  local packages=()

  command -v unzip >/dev/null 2>&1 || packages+=("unzip")
  command -v curl  >/dev/null 2>&1 || packages+=("curl")

  [[ "${#packages[@]}" -eq 0 ]] && return

  if command -v apt-get >/dev/null 2>&1; then
    log "安装缺失依赖: ${packages[*]}"
    run_as_root apt-get update
    run_as_root apt-get install -y "${packages[@]}"
  else
    fail "缺少以下依赖，请手动安装后重试: ${packages[*]}"
  fi
}

download_and_extract() {
  local arch version archive_name url

  arch="$(detect_arch)"
  version="$(resolve_version)"
  archive_name="yazi-${arch}.zip"
  url="https://github.com/sxyazi/yazi/releases/download/${version}/${archive_name}"

  TMP_DIR="$(mktemp -d)"

  log "下载 Yazi ${version} (${arch})..."
  curl -fL --retry 3 --output "${TMP_DIR}/${archive_name}" "${url}"

  unzip -oq "${TMP_DIR}/${archive_name}" -d "${TMP_DIR}"

  printf '%s\n' "${TMP_DIR}/yazi-${arch}"
}

backup_target_if_needed() {
  local target="$1"

  if [[ -e "${target}" && ! -L "${target}" ]]; then
    local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "${target}" "${backup}"
    log "已备份现有文件: ${target} -> ${backup}"
  fi
}

install_files() {
  local source_dir="$1"

  [[ -x "${source_dir}/ya"   ]] || chmod +x "${source_dir}/ya"
  [[ -x "${source_dir}/yazi" ]] || chmod +x "${source_dir}/yazi"

  mkdir -p "${INSTALL_ROOT}" "${BIN_DIR}"
  rm -rf "${INSTALL_DIR}"
  mv "${source_dir}" "${INSTALL_DIR}"

  backup_target_if_needed "${BIN_DIR}/ya"
  backup_target_if_needed "${BIN_DIR}/yazi"

  ln -sfn "${INSTALL_DIR}/ya"   "${BIN_DIR}/ya"
  ln -sfn "${INSTALL_DIR}/yazi" "${BIN_DIR}/yazi"
}

detect_shell_name() {
  local shell_path="${SHELL:-}"

  if [[ -z "${shell_path}" ]]; then
    printf 'sh\n'
    return
  fi

  basename -- "${shell_path}"
}

print_path_fix_instructions() {
  local shell_name rc_file rc_dir
  shell_name="$(detect_shell_name)"

  case "${shell_name}" in
    fish)
      rc_file="${HOME}/.config/fish/config.fish"
      rc_dir="$(dirname -- "${rc_file}")"
      cat <<EOF
[yazi-install] 如果当前 shell 还找不到 yazi，可按下面处理:
[yazi-install]   先让当前会话立即生效:
[yazi-install]     fish_add_path ${BIN_DIR}
[yazi-install]   再写入配置，供后续 shell 自动生效:
[yazi-install]     mkdir -p "${rc_dir}"
[yazi-install]     grep -Fqx 'fish_add_path \$HOME/.local/bin' "${rc_file}" 2>/dev/null || echo 'fish_add_path \$HOME/.local/bin' >> "${rc_file}"
[yazi-install]     source "${rc_file}"
EOF
      ;;
    zsh)
      rc_file="${HOME}/.zshrc"
      cat <<EOF
[yazi-install] 如果当前 shell 还找不到 yazi，可按下面处理:
[yazi-install]   先让当前会话立即生效:
[yazi-install]     export PATH="${BIN_DIR}:\$PATH"
[yazi-install]   再写入配置，供后续 shell 自动生效:
[yazi-install]     grep -Fqx 'export PATH="\$HOME/.local/bin:\$PATH"' "${rc_file}" 2>/dev/null || echo 'export PATH="\$HOME/.local/bin:\$PATH"' >> "${rc_file}"
[yazi-install]     source "${rc_file}"
EOF
      ;;
    *)
      rc_file="${HOME}/.bashrc"
      cat <<EOF
[yazi-install] 如果当前 shell 还找不到 yazi，可按下面处理:
[yazi-install]   先让当前会话立即生效:
[yazi-install]     export PATH="${BIN_DIR}:\$PATH"
[yazi-install]   再写入配置，供后续 shell 自动生效:
[yazi-install]     grep -Fqx 'export PATH="\$HOME/.local/bin:\$PATH"' "${rc_file}" 2>/dev/null || echo 'export PATH="\$HOME/.local/bin:\$PATH"' >> "${rc_file}"
[yazi-install]     source "${rc_file}"
EOF
      ;;
  esac
}

print_summary() {
  cat <<EOF
[yazi-install] 安装完成
[yazi-install] 可执行文件:
[yazi-install]   ${BIN_DIR}/yazi
[yazi-install]   ${BIN_DIR}/ya
EOF

  print_path_fix_instructions
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version|-v)
        [[ $# -ge 2 ]] || fail "--version 需要一个参数 (例: v26.1.22)"
        TARGET_VERSION="$2"
        shift 2
        ;;
      --help|-h)
        cat <<EOF
用法: install.sh [选项]

选项:
  --version, -v <版本>  安装指定版本 (例: v26.1.22)，默认安装最新版本
  --help, -h            显示此帮助

示例:
  bash install.sh
  bash install.sh --version v26.1.22
  curl -fsSL https://raw.githubusercontent.com/Undefinedefity/yazi-ubuntu-quick-start/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/Undefinedefity/yazi-ubuntu-quick-start/main/install.sh | bash -s -- --version v26.1.22
EOF
        exit 0
        ;;
      *)
        fail "未知参数: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  check_system
  ensure_packages

  local source_dir
  source_dir="$(download_and_extract)"

  if [[ ! -f "${source_dir}/yazi" || ! -f "${source_dir}/ya" ]]; then
    fail "安装源目录不完整: ${source_dir}"
  fi

  install_files "${source_dir}"
  print_summary
}

main "$@"
