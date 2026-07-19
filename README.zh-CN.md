<div align="center">

# PinyinTab

**以音寻字，一键成径。**

在 Bash 或 Zsh 中输入拼音，按下 <kbd>Tab</kbd>，补全真实中文路径。

[English](README.md) · [安装](#安装) · [兼容范围](#兼容范围) · [项目文档](#项目文档)

[![CI](https://github.com/hhhSyyyShhh/pinyintab/actions/workflows/ci.yml/badge.svg)](https://github.com/hhhSyyyShhh/pinyintab/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hhhSyyyShhh/pinyintab?display_name=tag)](https://github.com/hhhSyyyShhh/pinyintab/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Linux%20x86__64%20%7C%20macOS%20arm64-lightgrey)](#兼容范围)

</div>

PinyinTab 是面向中文文件名和目录名的原生终端补全插件。它不会重命名文件、创建磁盘别名、挂载虚拟文件系统，也不会修改 Python、Java、Julia 等解释器。Shell 会在命令执行前，把输入的拼音替换为真实中文路径。

```text
python3 jiujiuchengfabiao.py<Tab>
        ↓
python3 九九乘法表.py
```

它也支持多级路径和歧义候选的继续缩小：

```text
cd ceshimulu/neibuwenjiant<Tab>     → cd 测试目录/内部文件夹/
python3 jiujiu<Tab>                 → 展示多个“九九…”候选
python3 九九cf<Tab>                 → python3 九九乘法表.py
```

## 核心特点

- 使用普通 <kbd>Tab</kbd> 完成补全，不打开模糊搜索界面，也不进入虚拟目录。
- 支持全拼、首字母、真实中文前缀以及“中文 + 拼音”混合缩小候选。
- 支持用拼音逐层解析父目录和子路径。
- 根据命令语义区分目录、普通文件和 Java 类名。
- `ptab on` 与 `ptab off` 可逆，关闭后恢复原来的 Shell 补全器。
- Linux Bash 与 macOS Zsh 共用一个 Rust 核心。
- 不需要后台服务、不需要 FUSE，补全过程不联网。

## 安装

### 安装预编译版本

普通用户不需要安装 Rust，安装过程也不需要 `sudo`：

```bash
curl --proto '=https' --tlsv1.2 -fsSLO \
  https://raw.githubusercontent.com/hhhSyyyShhh/pinyintab/main/scripts/install-online.sh
less install-online.sh
bash install-online.sh
```

安装后重新打开终端，或者按照安装器提示重新加载 Shell 配置。以后打开新终端时 PinyinTab 会自动启用。

也可以从 [GitHub Releases](https://github.com/hhhSyyyShhh/pinyintab/releases) 手动下载与系统对应的压缩包，验证 `.sha256` 文件，解压后运行：

```bash
./install.sh
```

### 从源码安装

只有从源码编译时才需要 Rust 1.66 或更高版本：

```bash
git clone https://github.com/hhhSyyyShhh/pinyintab.git
cd pinyintab
./scripts/install-from-source.sh
```

### 卸载

在 Release 解压目录或源码目录中运行：

```bash
./uninstall.sh
```

卸载器会删除 `.bashrc` 和 `.zshrc` 中带有 PinyinTab 边界标记的配置，以及 `~/.local` 下安装的程序；安装时生成的配置备份不会自动删除。

## 使用方法

```bash
ptab on       # 在当前终端启用
ptab off      # 关闭并恢复原有补全器
ptab status   # 查看当前状态
ptab doctor   # 查看版本、系统、架构、Shell 和启用状态
ptab version
```

启用以后直接使用原来的命令：

```bash
cd ceshimulu<Tab>
cat xiangmushuoming.md<Tab>
python3 ceshi.py<Tab>
julia chengfakoujuebiao.jl<Tab>
javac chengfakoujuebiao.java<Tab>
java chengfakoujuebiao<Tab>
```

按下 Tab 后，命令行里出现的是磁盘上的真实中文名称。拼音只是一种输入查询，不是一个按下回车后仍然存在的虚拟文件名。

## 兼容范围

v0.3 首发只正式构建两个目标：

| 平台 | 架构 | Shell | Release 目标 | 状态 |
|---|---|---|---|---|
| Ubuntu Linux 22.04+ | x86_64 / AMD64 | Bash | `x86_64-unknown-linux-gnu` | 正式支持并测试 |
| macOS 14+ | Apple M1 或更新芯片 | Zsh | `aarch64-apple-darwin` | 正式支持并测试 |
| 其他 glibc Linux | x86_64 / AMD64 | Bash 或 Zsh | 可尝试同一 Linux 包 | 预期可用，但暂不保证 |
| Linux ARM64 | arm64 | Bash 或 Zsh | — | 暂不发布 |
| Intel Mac | x86_64 | Zsh | — | 暂不发布 |
| Windows | x86_64 / arm64 | PowerShell | — | 后续路线图 |

所以“Linux 都适配”并不准确。当前 Linux 包使用 GNU/glibc 目标：Ubuntu、Debian等同架构系统更有希望直接运行；Alpine/musl、非常旧的 glibc 和非 x86_64 机器需要单独构建。

PinyinTab 主要处理普通本地路径参数。远程 `host:path`、URL、here-document、程序自定义参数语法，以及复杂第三方补全器可能需要单独适配，详见[兼容边界](docs/COMPATIBILITY.md)。

## 工作原理

```text
用户输入拼音
    ↓
Bash/Zsh 判断当前参数是不是路径
    ↓
ptab 扫描当前层目录并生成拼音候选
    ↓
Shell 写入真实中文路径
    ↓
cd / Python / Java / Julia / cat 收到普通路径
```

PinyinTab 并不直接修改解释器，它是在解释器进程启动以前完成路径替换。组件和安全边界详见[架构文档](docs/ARCHITECTURE.md)。

## 项目文档

- [系统架构](docs/ARCHITECTURE.md)
- [兼容边界](docs/COMPATIBILITY.md)
- [发布、版本号与 GitHub Release 流程](docs/RELEASE_GUIDE.md)
- [竞品分析与 Common Criteria](docs/COMPETITOR_ANALYSIS.md)
- [Bug 历史与回归测试](docs/BUG_REPORT.md)
- [技术栈详细介绍](docs/技术栈与实现说明.md)
- [Linux 部署记录](docs/Linux版本部署与测试.md)

## 开发测试

```bash
cargo test --locked
cargo build --release --locked
./scripts/test-completion.sh    # Bash
./scripts/test-macos.zsh       # macOS Zsh
```

`demo-source` 提供 Python、Java、Julia、JavaScript、Ruby、Perl、C、Rust、Swift 和 Bash 的中文文件名示例。

## 路线图

- [x] Bash 与 Zsh 原生补全
- [x] 全拼、首字母、混合缩小候选和多级路径
- [x] Linux x86_64 与 macOS arm64 Release 打包
- [ ] 更多多音字词组覆盖和自定义字典
- [ ] Fish Shell 集成
- [ ] Linux ARM64 与 Intel macOS 构建
- [ ] Windows PowerShell 原型

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=hhhSyyyShhh/pinyintab&type=Date)](https://star-history.com/#hhhSyyyShhh/pinyintab&Date)

创建公开 GitHub 仓库并配置仓库所有者以后，Star History 曲线才会开始产生数据。

## 参与贡献与安全问题

提交 Pull Request 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。如果发现可能泄露路径信息或造成 Shell 注入的安全问题，请按照 [SECURITY.md](SECURITY.md) 私下报告，不要直接创建公开 Issue。

## 开源许可证

PinyinTab 使用 [MIT License](LICENSE)。
