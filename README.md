# yazi-ubuntu-quick-start

面向 Linux（主要针对 Ubuntu）的 Yazi 一键安装脚本，支持多架构、任意 Ubuntu 版本。

## 特性

- 支持任意 Ubuntu 版本（22.04、24.04、25.04 等）及其他 Linux 发行版
- 支持多架构：x86_64、aarch64/arm64、i686、riscv64、sparc64
- 默认安装最新版本，支持通过 `--version` 指定版本
- 用户目录安装，不污染系统路径，方便回滚
- 提供配套卸载脚本

## 安装位置

- 程序目录：`~/.local/opt/yazi/`
- 命令链接：`~/.local/bin/yazi`
- 命令链接：`~/.local/bin/ya`

## 快速开始

### 方法一：curl 一键安装（无需 clone 仓库）

安装最新版本：

```bash
curl -fsSL https://raw.githubusercontent.com/Undefinedefity/yazi-ubuntu-quick-start/main/install.sh | bash
```

安装指定版本：

```bash
curl -fsSL https://raw.githubusercontent.com/Undefinedefity/yazi-ubuntu-quick-start/main/install.sh | bash -s -- --version v26.1.22
```

卸载：

```bash
curl -fsSL https://raw.githubusercontent.com/Undefinedefity/yazi-ubuntu-quick-start/main/uninstall.sh | bash
```

### 方法二：clone 仓库后运行

```bash
git clone https://github.com/Undefinedefity/yazi-ubuntu-quick-start.git
cd yazi-ubuntu-quick-start
chmod +x install.sh uninstall.sh
./install.sh
```

安装指定版本：

```bash
./install.sh --version v26.1.22
```

## 验证安装

```bash
yazi --version
ya --version
```

如果当前 shell 仍提示找不到命令，安装脚本会按 shell 类型输出对应的 PATH 修复命令。

## 卸载

```bash
./uninstall.sh
```

## 支持架构

| `uname -m` | 对应 Yazi 构建目标 |
|---|---|
| x86_64 / amd64 | x86_64-unknown-linux-gnu |
| aarch64 / arm64 | aarch64-unknown-linux-gnu |
| i686 / i386 | i686-unknown-linux-gnu |
| riscv64 | riscv64gc-unknown-linux-gnu |
| sparc64 | sparc64-unknown-linux-gnu |

## 说明

- 安装脚本通过 GitHub API 自动获取最新版本；若 API 不可达，回退至内置版本号
- 若 `~/.local/bin/yazi` 或 `~/.local/bin/ya` 在安装前是普通文件，脚本会先备份为 `<name>.bak.<timestamp>`
- 脚本可能调用 `sudo apt-get` 安装 `unzip`、`curl`（如果缺失）；非 apt 系统请手动保证这两个命令已安装
- 脚本不会修改 shell 配置文件，只输出建议命令
- 重复安装会覆盖已有安装目录
- 卸载脚本只删除明确指向当前安装目录的符号链接，对不属于本脚本的链接或普通文件会跳过
