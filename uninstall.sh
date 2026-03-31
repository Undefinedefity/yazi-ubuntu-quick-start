#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="${HOME}/.local/opt"
INSTALL_DIR="${INSTALL_ROOT}/yazi"
BIN_DIR="${HOME}/.local/bin"
CHANGES=0

log() {
  printf '[yazi-uninstall] %s\n' "$*" >&2
}

mark_changed() {
  CHANGES=$((CHANGES + 1))
}

latest_backup_for() {
  local target="$1"
  local latest=""
  local candidate

  shopt -s nullglob
  for candidate in "${target}.bak."*; do
    [[ -e "${candidate}" ]] || continue
    latest="${candidate}"
  done
  shopt -u nullglob

  printf '%s\n' "${latest}"
}

restore_backup_if_available() {
  local target="$1"
  local backup

  if [[ -e "${target}" || -L "${target}" ]]; then
    return
  fi

  backup="$(latest_backup_for "${target}")"
  if [[ -z "${backup}" ]]; then
    return
  fi

  mv -- "${backup}" "${target}"
  log "已恢复备份: ${backup} -> ${target}"
  mark_changed
}

remove_managed_entry() {
  local name="$1"
  local target="${BIN_DIR}/${name}"
  local expected="${INSTALL_DIR}/${name}"
  local link_target=""

  if [[ -L "${target}" ]]; then
    link_target="$(readlink -- "${target}")"
    if [[ "${link_target}" == "${expected}" ]]; then
      rm -- "${target}"
      log "已删除符号链接: ${target}"
      mark_changed
    else
      log "跳过非本脚本创建的符号链接: ${target} -> ${link_target}"
      return
    fi
  elif [[ -e "${target}" ]]; then
    log "跳过非链接文件: ${target}"
    return
  fi

  restore_backup_if_available "${target}"
}

remove_install_dir() {
  if [[ -d "${INSTALL_DIR}" ]]; then
    rm -rf -- "${INSTALL_DIR}"
    log "已删除安装目录: ${INSTALL_DIR}"
    mark_changed
  else
    log "安装目录不存在，跳过: ${INSTALL_DIR}"
  fi

  rmdir --ignore-fail-on-non-empty "${INSTALL_ROOT}" 2>/dev/null || true
}

print_summary() {
  if [[ "${CHANGES}" -eq 0 ]]; then
    log "未发现由当前安装脚本管理的 yazi 安装痕迹"
    return
  fi

  cat <<EOF
[yazi-uninstall] 卸载完成
[yazi-uninstall] 已处理路径:
[yazi-uninstall]   ${INSTALL_DIR}
[yazi-uninstall]   ${BIN_DIR}/yazi
[yazi-uninstall]   ${BIN_DIR}/ya
EOF
}

main() {
  remove_managed_entry "yazi"
  remove_managed_entry "ya"
  remove_install_dir
  print_summary
}

main "$@"
