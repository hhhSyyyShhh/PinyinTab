<div align="center">

# PinyinTab

**以音寻字，一键成径。**

面向 Bash 与 Zsh 的原生中文路径拼音补全插件。

[English](README.md) · [安装](#安装) · [使用](#使用) · [兼容范围](#兼容范围)

[![CI](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml/badge.svg)](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hhhSyyyShhh/PinyinTab?display_name=tag)](https://github.com/hhhSyyyShhh/PinyinTab/releases)
[![Stars](https://img.shields.io/github/stars/hhhSyyyShhh/PinyinTab?style=flat)](https://github.com/hhhSyyyShhh/PinyinTab/stargazers)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

PinyinTab 允许用户输入中文文件名或目录名的拼音，按下 <kbd>Tab</kbd> 后插入真实路径。它不会重命名文件、挂载虚拟文件系统，也不会修改解释器。

[![PinyinTab 终端演示](assets/demo.gif)](assets/demo.mp4)

```text
python3 jiujiuchengfabiao.py<Tab>
        ↓
python3 九九乘法表.py
```

## 功能

- 支持全拼、首字母、真实中文前缀以及“中文 + 拼音”混合缩小候选。
- 支持用拼音逐层补全父目录和多级路径。
- 多个候选存在时保留输入，可继续键入并精确筛选。
- 根据命令语义区分目录、文件和 Java 类名。
- `ptab on` / `ptab off` 可逆，关闭时恢复原 Shell 补全器。
- Linux Bash 与 macOS Zsh 共用同一个 Rust 核心。
- 补全时不需要后台服务、FUSE 或网络连接。

## 安装

### 预编译版本

安装仅作用于当前用户，不需要 `sudo`，也不需要 Rust：

```bash
curl --proto '=https' --tlsv1.2 -fL \
  https://github.com/hhhSyyyShhh/PinyinTab/releases/latest/download/install-online.sh \
  -o install-online.sh
less install-online.sh
bash install-online.sh
```

安装后重新打开终端。如果所在网络无法访问 GitHub，请从 [Releases](https://github.com/hhhSyyyShhh/PinyinTab/releases) 手动下载对应压缩包和 `.sha256` 文件，校验并解压后运行 `./install.sh`。

### 从源码安装

只有源码构建需要 Rust 1.66 或更新版本：

```bash
git clone https://github.com/hhhSyyyShhh/PinyinTab.git
cd PinyinTab
./scripts/install-from-source.sh
```

### 卸载

在源码目录或 Release 解压目录中运行：

```bash
./uninstall.sh
```

卸载器会删除 PinyinTab 写入的 Shell 配置块和 `~/.local` 下的安装文件，并保留安装时生成的配置备份。

## 使用

```bash
ptab on       # 在当前 Shell 启用
ptab off      # 关闭并恢复原补全器
ptab status   # 查看 Shell 集成状态
ptab doctor   # 查看版本、系统、架构、Shell 和状态
ptab version
```

启用后照常输入命令，并在拼音路径处按 <kbd>Tab</kbd>：

```bash
cd ceshimulu<Tab>
cat xiangmushuoming.md<Tab>
python3 ceshi.py<Tab>
julia chengfakoujuebiao.jl<Tab>
javac chengfakoujuebiao.java<Tab>
java chengfakoujuebiao<Tab>
```

补全后命令行中出现的是磁盘上的真实中文名称。拼音只在按 Tab 时作为查询使用，不是按 Enter 后仍然有效的虚拟文件名。

## 兼容范围

| 平台 | 架构 | Shell | Release 目标 | 状态 |
|---|---|---|---|---|
| Ubuntu 22.04+ | x86_64 / AMD64 | Bash | `x86_64-unknown-linux-gnu` | 已测试 |
| macOS 14+ | Apple Silicon | Zsh | `aarch64-apple-darwin` | 已测试 |
| 其他 glibc Linux | x86_64 / AMD64 | Bash 或 Zsh | Linux 包 | 预期可用，不保证 |
| Alpine/musl、Linux ARM64、Intel Mac、Windows | — | — | — | 暂未发布 |

PinyinTab 面向普通本地路径参数。远程 `host:path`、URL、here-document、程序自定义参数语法和第三方补全器可能需要单独适配，详见[兼容边界](docs/COMPATIBILITY.md)。

## 工作原理

```text
在 Bash/Zsh 中输入拼音
          ↓
Shell 识别当前路径参数和命令场景
          ↓
Rust 扫描当前一层目录并匹配真实名、全拼和首字母
          ↓
Shell 展示或插入真实中文路径
          ↓
cd、Python、Java、Julia 等命令正常执行
```

补全核心逐层解析父目录，只在结果安全时插入路径。模块结构与安全边界见[架构文档](docs/ARCHITECTURE.md)。

## 开发

```bash
cargo fmt --all -- --check
cargo test --locked --all-targets
cargo clippy --locked --all-targets -- -D warnings
cargo build --release --locked
./scripts/test-completion.sh
./scripts/test-macos.zsh
```

CI 会在 Ubuntu 和 macOS 上运行 Rust 与 Shell 测试、检查格式和 Clippy，并要求 Rust 行覆盖率不低于 70%。`demo-source` 提供 Python、Java、Julia、JavaScript、Ruby、Perl、C、Rust、Swift 和 Bash 的中文文件名示例。

## 贡献与安全

提交 Pull Request 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。用户可见变化应记录在 [CHANGELOG.md](CHANGELOG.md)。可能造成路径信息泄露或 Shell 注入的安全问题请按照 [SECURITY.md](SECURITY.md) 私下报告，不要创建公开 Issue。

## 许可证

PinyinTab 使用 [MIT License](LICENSE)。
