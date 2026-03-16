# yazi-ubuntu-quick-start

一个面向 Ubuntu 24.04 x86_64 的 Yazi 快速安装仓库。

仓库内提供：

- `install-yazi-ubuntu24-x86_64.sh`：安装脚本
- `uninstall-yazi-ubuntu24-x86_64.sh`：卸载脚本
- `yazi-x86_64-unknown-linux-gnu.zip`：Yazi Linux x86_64 压缩包

适合想在 Ubuntu 24.04 上快速安装 Yazi，又不想手动解压、摆放目录和处理符号链接的场景。

## 特性

- 仅支持 `Ubuntu 24.04`
- 仅支持 `x86_64 / amd64`
- 优先使用仓库内自带压缩包安装
- 自动补齐缺失依赖：`unzip`、`curl`
- 将程序安装到用户目录，不污染系统目录
- 自动创建 `~/.local/bin/yazi` 和 `~/.local/bin/ya`
- 如果当前 shell 还找不到 `yazi`，脚本会直接给出可执行的 PATH 修复命令
- 提供配套卸载脚本，可移除本仓库安装的版本

## 安装位置

安装脚本会使用以下路径：

- 程序目录：`~/.local/opt/yazi-x86_64-unknown-linux-gnu`
- 命令链接：`~/.local/bin/yazi`
- 命令链接：`~/.local/bin/ya`

## 快速开始

给脚本加执行权限：

```bash
chmod +x install-yazi-ubuntu24-x86_64.sh
chmod +x uninstall-yazi-ubuntu24-x86_64.sh
```

执行安装：

```bash
./install-yazi-ubuntu24-x86_64.sh
```

安装完成后验证：

```bash
yazi --version
ya --version
```

如果当前 shell 仍然提示找不到 `yazi`，安装脚本会按你的 shell 类型输出对应的修复命令。常见情况是把 `~/.local/bin` 加入 PATH 后重新加载 shell 配置。

## 卸载

执行：

```bash
./uninstall-yazi-ubuntu24-x86_64.sh
```

卸载脚本会：

- 删除 `~/.local/opt/yazi-x86_64-unknown-linux-gnu`
- 删除指向该安装目录的 `~/.local/bin/yazi`
- 删除指向该安装目录的 `~/.local/bin/ya`
- 如果安装前这两个路径是普通文件，且安装时被备份为 `.bak.*`，则尝试恢复最新备份

## 安装脚本行为说明

安装脚本的大致流程：

1. 检查系统是否为 Ubuntu 24.04 且架构为 x86_64
2. 检查并安装缺失依赖
3. 优先使用仓库内的 `yazi-x86_64-unknown-linux-gnu.zip`
4. 解压后安装到 `~/.local/opt`
5. 在 `~/.local/bin` 下创建 `yazi` 和 `ya` 的符号链接
6. 输出 PATH 修复建议

如果 `~/.local/bin/yazi` 或 `~/.local/bin/ya` 在安装前是普通文件，脚本会先将其备份为：

```text
~/.local/bin/yazi.bak.<timestamp>
~/.local/bin/ya.bak.<timestamp>
```

## 重复执行说明

重复执行安装脚本通常不会报错，但它不是“检测到已安装就跳过”的模式，而是“重新覆盖安装”的模式：

- 会删除旧的安装目录后重新安装
- 会重新创建 `~/.local/bin/yazi` 和 `~/.local/bin/ya` 链接
- 如果你手动修改过安装目录中的文件，这些修改会被覆盖

卸载脚本则相对保守：

- 只删除明确指向当前安装目录的符号链接
- 对非本脚本创建的链接或普通文件会跳过，不会强行删除

## 注意事项

- 安装脚本可能会调用 `sudo apt-get update` 和 `sudo apt-get install`
- 当前仓库面向单用户目录安装，不会写入 `/usr/local/bin`
- 脚本不会自动修改你的 shell 配置文件，只会输出建议命令
- 不建议并发执行安装脚本或卸载脚本

## 适用场景

- 想快速装上 Yazi
- 希望安装在用户目录，方便回滚
- 希望保留简单、可读、可修改的 shell 脚本方案
