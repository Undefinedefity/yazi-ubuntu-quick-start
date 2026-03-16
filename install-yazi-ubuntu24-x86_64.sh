#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FLOW_FILE="${SCRIPT_DIR}/flow.MD"
ARCHIVE_NAME="yazi-x86_64-unknown-linux-gnu.zip"
PACKAGE_DIR_NAME="yazi-x86_64-unknown-linux-gnu"
LOCAL_ARCHIVE="${SCRIPT_DIR}/${ARCHIVE_NAME}"
LOCAL_PACKAGE_DIR="${SCRIPT_DIR}/${PACKAGE_DIR_NAME}"
INSTALL_ROOT="${HOME}/.local/opt"
INSTALL_DIR="${INSTALL_ROOT}/${PACKAGE_DIR_NAME}"
BIN_DIR="${HOME}/.local/bin"
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

ensure_packages() {
  local packages=()
  local need_unzip=0

  if [[ -f "${LOCAL_ARCHIVE}" || ! -d "${LOCAL_PACKAGE_DIR}" ]]; then
    need_unzip=1
  fi

  if [[ "${need_unzip}" -eq 1 ]] && ! command -v unzip >/dev/null 2>&1; then
    packages+=("unzip")
  fi

  if [[ ! -f "${LOCAL_ARCHIVE}" && ! -d "${LOCAL_PACKAGE_DIR}" ]]; then
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
      packages+=("curl")
    fi
  fi

  if [[ "${#packages[@]}" -eq 0 ]]; then
    return
  fi

  log "安装缺失依赖: ${packages[*]}"
  run_as_root apt-get update
  run_as_root apt-get install -y "${packages[@]}"
}

check_system() {
  if [[ ! -r /etc/os-release ]]; then
    fail "无法读取 /etc/os-release，无法确认系统版本"
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    fail "此脚本仅支持 Ubuntu 24.04，当前为 ${ID:-unknown} ${VERSION_ID:-unknown}"
  fi

  case "$(uname -m)" in
    x86_64|amd64)
      ;;
    *)
      fail "此脚本仅支持 x86_64，当前架构为 $(uname -m)"
      ;;
  esac
}

resolve_download_url() {
  local url=""

  if [[ -f "${FLOW_FILE}" ]]; then
    url="$(
      awk '/^https:\/\/github\.com\/sxyazi\/yazi\/releases\/download\/[^[:space:]]+\/yazi-x86_64-unknown-linux-gnu\.zip$/ { print; exit }' "${FLOW_FILE}"
    )"
  fi

  if [[ -z "${url}" ]]; then
    url="https://github.com/sxyazi/yazi/releases/download/v26.1.22/yazi-x86_64-unknown-linux-gnu.zip"
  fi

  printf '%s\n' "${url}"
}

download_archive() {
  local url="$1"
  local target="$2"

  log "未发现本地压缩包，开始下载: ${url}"

  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --output "${target}" "${url}"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -O "${target}" "${url}"
    return
  fi

  fail "缺少 curl/wget，无法下载压缩包"
}

prepare_source_tree() {
  TMP_DIR="$(mktemp -d)"

  if [[ -f "${LOCAL_ARCHIVE}" ]]; then
    log "使用本地压缩包: ${LOCAL_ARCHIVE}"
    unzip -oq "${LOCAL_ARCHIVE}" -d "${TMP_DIR}"
    printf '%s\n' "${TMP_DIR}/${PACKAGE_DIR_NAME}"
    return
  fi

  if [[ -d "${LOCAL_PACKAGE_DIR}" ]]; then
    log "本地压缩包不存在，使用已解压目录: ${LOCAL_PACKAGE_DIR}"
    cp -a "${LOCAL_PACKAGE_DIR}" "${TMP_DIR}/"
    printf '%s\n' "${TMP_DIR}/${PACKAGE_DIR_NAME}"
    return
  fi

  local downloaded_archive="${TMP_DIR}/${ARCHIVE_NAME}"
  download_archive "$(resolve_download_url)" "${downloaded_archive}"
  unzip -oq "${downloaded_archive}" -d "${TMP_DIR}"
  printf '%s\n' "${TMP_DIR}/${PACKAGE_DIR_NAME}"
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

  [[ -x "${source_dir}/ya" ]] || chmod +x "${source_dir}/ya"
  [[ -x "${source_dir}/yazi" ]] || chmod +x "${source_dir}/yazi"

  mkdir -p "${INSTALL_ROOT}" "${BIN_DIR}"
  rm -rf "${INSTALL_DIR}"
  mv "${source_dir}" "${INSTALL_DIR}"

  backup_target_if_needed "${BIN_DIR}/ya"
  backup_target_if_needed "${BIN_DIR}/yazi"

  ln -sfn "${INSTALL_DIR}/ya" "${BIN_DIR}/ya"
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

main() {
  check_system
  ensure_packages

  local source_dir
  source_dir="$(prepare_source_tree)"

  if [[ ! -f "${source_dir}/yazi" || ! -f "${source_dir}/ya" ]]; then
    fail "安装源目录不完整: ${source_dir}"
  fi

  install_files "${source_dir}"
  print_summary
}

main "$@"
