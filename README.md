<div align="center">

# PinyinTab

面向 Bash 与 Zsh 的原生中文路径拼音补全插件。

中文路径拼音补全：输入拼音，按 Tab，得到真实路径。 | Type Pinyin, press Tab, get the real path.

[English](README.en.md) · [安装](#安装) · [使用](#使用) · [中英文切换](#中英文候选切换) · [兼容范围](#兼容范围)

[![CI](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml/badge.svg)](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hhhSyyyShhh/PinyinTab?display_name=tag)](https://github.com/hhhSyyyShhh/PinyinTab/releases)
[![Stars](https://img.shields.io/github/stars/hhhSyyyShhh/PinyinTab?style=flat)](https://github.com/hhhSyyyShhh/PinyinTab/stargazers)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

在 Bash/Zsh 中输入中文文件名或目录名的全拼、首字母，按 <kbd>Tab</kbd> 插入真实路径。文件名、文件内容和当前工作目录保持不变。

[![PinyinTab 终端演示](assets/demo.gif)](assets/demo.mp4)

> 基础补全演示，录制于早期版本。当前候选切换操作见[使用说明](#中英文候选切换)。

```text
python3 jiujiuchengfabiao.py<Tab>
        ↓
python3 九九乘法表.py
```

## 功能

- 支持全拼、首字母、真实中文前缀以及“中文 + 拼音”混合缩小候选。
- 支持用拼音逐层补全父目录和多级路径。
- 完整真实文件名优先，避免把已经输入准确的名称再扩展为其他文件。
- 默认 Tab 优先非中文候选；可用 Control+X 后按 c/e 明确选择中文或非中文。
- 完整中文名称也能反向查找真实存在的全拼/首字母文件，无需重新输入查询。
- 同组多个候选仍需继续输入筛选，不自动猜选。
- 根据命令语义区分目录、文件和 Java 类名。
- `ptab on` / `ptab off` 可逆，关闭时恢复原 Shell 补全器。
- Linux Bash 与 macOS Zsh 共用同一个 Rust 核心。
- 补全时不需要后台服务、FUSE 或网络连接。

## 安装

### 预编译版本

预编译包采用用户级安装，无需 Rust、管理员权限或 FUSE。安装脚本自动识别系统与处理器架构。

支持 Ubuntu 22.04/24.04、CentOS Stream 9 x86_64，以及 Apple 芯片 Mac。其他平台见[兼容范围](#兼容范围)。

**第 1 步：打开终端。** Mac：“应用程序 → 实用工具 → 终端”；Linux：本地终端或 SSH。以下命令按代码框依次执行，不包含提示符 `$`。

**第 2 步：下载安装脚本。**

```bash
curl --proto '=https' --tlsv1.2 -fL --connect-timeout 10 --max-time 60 \
  https://github.com/hhhSyyyShhh/PinyinTab/releases/latest/download/install-online.sh \
  -o install-online.sh
```

下载失败时，先按[网络排查说明](#下载失败怎么办)处理，再重新执行此步。下载完成后继续安装。

**第 3 步：检查脚本语法。** 没有输出表示语法检查通过；运行前可用文本编辑器查看脚本。语法检查不验证下载来源或脚本行为。

```bash
bash -n install-online.sh
```

**第 4 步：运行安装。** 它还会下载对应安装包和校验文件，检查 SHA-256，最后应看到 `PinyinTab installed successfully.`。

```bash
bash install-online.sh
```

**第 5 步：关闭当前终端窗口，重新打开一个终端**（服务器则重新登录 SSH），确认版本：

```bash
ptab version
```

该命令显示已安装版本。v0.6.1 起支持 `ptab update`；更早版本需先按本页步骤升级一次。

**第 6 步：手动开启补全。** 普通安装默认关闭，不会自动接管每个新终端。

```bash
ptab on
```

```bash
ptab status
```

状态为 `ON` 后即可使用。`<Tab>` 表示按 Tab 键。例如目录中有 `测试.py`，输入 `python3 ceshi.py`，按 Tab 补全后再按回车。

<details>
<summary>出现 command not found，或希望每个新终端自动开启？</summary>

确认安装成功后，Mac/Zsh 当前窗口可手动加载：

```zsh
source "$HOME/.local/share/pinyintab/pinyintab.zsh"
```

Linux/Bash 当前窗口可手动加载：

```bash
source "$HOME/.local/share/pinyintab/pinyintab.bash"
```

再运行 `ptab on`。如果脚本文件也不存在，说明安装未完成，应先查看安装报错。使用自定义 `ZDOTDIR` 的 Zsh 会写入该目录的 `.zshrc`。

如果明确希望自动开启，在第 4 步改用：

```bash
bash install-online.sh --enable-on-startup
```

</details>

### 下载失败怎么办

- `curl (7)` / `curl (28)`：连接失败或超时，先检查机器能否访问 GitHub。反复运行安装命令不能绕过网络限制，不要关闭 HTTPS 证书检查。
- `HTTP 403` 且提示 `API rate limit exceeded`：当前网络出口的 GitHub 匿名 API 配额已用完。等待配额恢复，或使用下面的手动安装；不要在公开反馈中粘贴账号 Token。其他 403 也可能来自网络访问策略，需要看具体错误信息。
- 下载脚本成功不代表安装包也能下载；后续还要访问 GitHub API、Release 附件及其重定向域名。
- 能在另一台电脑下载时，从 [Release 页面](https://github.com/hhhSyyyShhh/PinyinTab/releases/latest) 下载**对应系统的 `.tar.gz` 和同名 `.sha256` 两个文件**，再复制到目标机器。

手动安装示例：先在终端进入这两个文件所在的目录，然后按对应系统逐框执行。

<details>
<summary>Apple 芯片 Mac 手动安装</summary>

```zsh
shasum -a 256 -c pinyintab-v0.6.1-aarch64-apple-darwin.tar.gz.sha256
```

必须显示 `OK`；否则不要解压安装。

```zsh
tar -xzf pinyintab-v0.6.1-aarch64-apple-darwin.tar.gz
```

```zsh
cd pinyintab-v0.6.1-aarch64-apple-darwin
```

```zsh
bash install.sh
```

</details>

<details>
<summary>Ubuntu / CentOS Stream 9 x86_64 手动安装</summary>

```bash
sha256sum -c pinyintab-v0.6.1-x86_64-unknown-linux-gnu.tar.gz.sha256
```

必须显示 `OK`；否则不要解压安装。

```bash
tar -xzf pinyintab-v0.6.1-x86_64-unknown-linux-gnu.tar.gz
```

```bash
cd pinyintab-v0.6.1-x86_64-unknown-linux-gnu
```

```bash
bash install.sh
```

</details>

手动安装后重新打开终端，运行 `ptab version` 和 `ptab on`。SHA-256 用于完整性校验，安装包及校验文件仍应来自可信来源。

### 更新已安装版本

**v0.6.1 起**，在终端直接运行：

```bash
ptab update
```

它会检查最新稳定版，按系统下载对应安装包，校验 SHA-256 并检查新程序后再替换；没有更新时不重复安装，不自动降级。下载或校验失败不会删除旧版，替换后的检查失败会尝试回滚。

更新成功后，**关闭并重新打开终端**（SSH 重新连接），再依次执行：

```bash
ptab version
```

```bash
ptab on
```

更新不改 `.bashrc` / `.zshrc`，保留原来的手动或自动启用设置。下载临时文件和成功替换的旧安装副本会清理；个人配置、项目、手动下载的安装包不会删除。若遇到断电、强制终止或磁盘故障导致回滚失败，会保留恢复目录并报告位置，不继续清理备份。更新仍需要能访问 GitHub；失败时可用上面的手动安装方式。

### 从源码安装

只有源码构建需要 Rust 1.66 或更新版本：

```bash
git clone https://github.com/hhhSyyyShhh/PinyinTab.git
cd PinyinTab
./scripts/install-from-source.sh
```

### Oh My Zsh

安装好二进制后，把仓库克隆为 Oh My Zsh 自定义插件：

```zsh
git clone https://github.com/hhhSyyyShhh/PinyinTab.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/pinyintab"
```

在 `~/.zshrc` 的 `plugins=(...)` 中加入 `pinyintab`，重新打开 Zsh 即可。把插件加入列表本身就是明确启用，因此 Oh My Zsh 加载入口会自动开启补全。其他兼容的 Zsh 插件管理器也可以加载仓库根目录的 `pinyintab.plugin.zsh`。

### 卸载

运行已安装的卸载器：

```bash
bash "$HOME/.local/share/pinyintab/uninstall.sh"
```

卸载器会删除 PinyinTab 写入的 Shell 配置块和 `~/.local` 下的安装文件，并保留安装时生成的配置备份。
下载的压缩包和手动解压目录不会自动删除；确认没有个人文件后可自行清理。卸载后重新打开终端，以清除当前会话已加载的函数。

## 中英文候选切换

假设当前目录**只有** `cs1.py` 和 `测试1.py` 两个以 `cs1` 匹配的条目：

| 操作 | 命令行结果 |
|---|---|
| 输入 `vim cs1`，按 Tab | `vim cs1.py`，默认优先非中文 |
| 紧接着按 Control+X，松开后按 c | `vim 测试1.py` |
| 再按 Control+X，松开后按 e | `vim cs1.py` |
| 不先按 Tab，输入 `vim cs1` 后直接按 Control+X，再按 c | `vim 测试1.py` |

Mac 使用 **Control（⌃）**，不是 Command（⌘）。`Control+X, c` 是先按组合键，再按字母，不是同时按三个键；也不是直接按 Control+C/E。原来的中断与移到行尾功能不变。

- 已存在完整的 `c.py` / `cs1.py` 时，普通 Tab 不再扩展成其他名称；显式选择中文仍可访问对应中文候选。
- 没有英文候选时，普通 Tab 继续补全中文，例如 `ceshi1.py` → `测试1.py`。
- 直接输入 `vim 测试1.py`，光标紧挨文件名末尾，按 Control+X 后按 e，也能切为真实存在的 `cs1.py`；再按 c 可切回。它不依赖上一次 Tab，也适用于历史命令或粘贴的完整名称。
- 完整名称切换按全名对应，保留数字、扩展名和父目录。若同时存在 `cs1.py` 与 `ceshi1.py`，只展示两项并保留输入；没有对应文件则不改动。它们是不同的真实文件，不是同一文件的别名副本。
- `cs` 同时对应 `cs1.py/cs2.py/cs3.py` 时，会列出英文组；选择中文后列出 `测试1.py/测试2.py/测试3.py`，继续输入数字来缩小范围。多个候选不会强行选一个。
- “英文组”准确说是**名称不含汉字**的组；中英混合名属于中文组，判断对象是最后一级名称，不是整条父目录。
- 选择只作用于当前补全。空格后开始新参数，空查询展示两类非隐藏条目；编辑输入或移动光标后按当前词项重新查询。
- 仅处理 Shell 路径参数，不接管 Vim/Neovim 编辑区。

## 使用

```bash
ptab on       # 在当前 Shell 启用
ptab off      # 关闭并恢复原补全器
ptab status   # 查看 Shell 集成状态
ptab doctor   # 查看版本、系统、架构、Shell 和状态
ptab version
ptab update   # 检查并更新已安装版本；成功后重开终端
ptab --help   # 命令、选项、示例与使用边界（默认英文）
ptab help zh  # 中文帮助
```

帮助不改变补全状态。高级诊断接口见 `ptab help advanced zh`；
`on/off/status` 必须由当前终端加载的 Shell 集成执行，不能通过独立子进程改变父 Shell。

启用后照常输入命令，并在拼音路径处按 <kbd>Tab</kbd>：

```bash
cd ceshimulu<Tab>
./yunxingchengxu<Tab>
cat xiangmushuoming.md<Tab>
python3 ceshi.py<Tab>
julia chengfakoujuebiao.jl<Tab>
javac chengfakoujuebiao.java<Tab>
java chengfakoujuebiao<Tab>
```

补全后命令行中出现的是磁盘上的真实中文名称。拼音只在按 Tab 时作为查询使用，不是按 Enter 后仍然有效的虚拟文件名。

`./`、`../`、绝对路径位于命令位置时，会补全可执行文件和可继续进入的目录。文件仍需执行权限，以及有效的二进制格式或脚本解释器声明；Tab 本身不会执行文件。文件参数也会保留目录候选，方便逐级输入路径。详见[命令上下文测试范围](docs/COMPATIBILITY.md#v041-命令上下文回归范围)。

## 兼容范围

| 平台 | 架构 | Shell | Release 目标 | 状态 |
|---|---|---|---|---|
| Ubuntu 22.04 / 24.04 | x86_64 / AMD64 | Bash | `x86_64-unknown-linux-gnu` | 已测试 |
| CentOS Stream 9 | x86_64 / AMD64 | Bash | `x86_64-unknown-linux-gnu` | 已测试 |
| macOS 14+ | Apple Silicon | Zsh | `aarch64-apple-darwin` | 已测试 |
| 其他 glibc 2.34+ Linux | x86_64 / AMD64 | Bash 或 Zsh | Linux 包 | 预期可用，不保证 |
| Alpine/musl、Linux ARM64、Intel Mac、Windows | — | — | — | 暂未发布 |

Linux 安装包要求 glibc 2.34 或更新版本。已经停止维护的 CentOS Linux 7/8 和 CentOS Stream 8 不在支持范围内。PinyinTab 面向普通本地路径参数；远程 `host:path`、URL、here-document、程序自定义参数语法和第三方补全器可能需要单独适配，详见[兼容边界](docs/COMPATIBILITY.md)。

## 工作原理

```text
在 Bash/Zsh 中输入拼音
          ↓
Shell 识别当前路径参数和命令场景
          ↓
Rust 扫描当前一层目录并匹配真实名、全拼和首字母
          ↓
Shell 展示或插入真实路径
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

## 版本历史

PinFS 原型阶段的源码已补录归档：

[0.1.0](https://github.com/hhhSyyyShhh/PinyinTab/releases/tag/v0.1.0) →
[0.2.0](https://github.com/hhhSyyyShhh/PinyinTab/releases/tag/v0.2.0) →
[0.2.1](https://github.com/hhhSyyyShhh/PinyinTab/releases/tag/v0.2.1) →
[0.2.2](https://github.com/hhhSyyyShhh/PinyinTab/releases/tag/v0.2.2) →
[0.2.3](https://github.com/hhhSyyyShhh/PinyinTab/releases/tag/v0.2.3) →
[0.2.4](https://github.com/hhhSyyyShhh/PinyinTab/releases/tag/v0.2.4) →
[PinyinTab 0.3.0](https://github.com/hhhSyyyShhh/PinyinTab/releases/tag/v0.3.0) →
[当前版本](https://github.com/hhhSyyyShhh/PinyinTab/releases/latest)。

早期快照于 2026-10-27 从本地存档补录，仅供追溯。当前安装请使用最新版。

## 贡献与安全

提交 Pull Request 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。用户可见变化应记录在 [CHANGELOG.md](CHANGELOG.md)。可能造成路径信息泄露或 Shell 注入的安全问题请按照 [SECURITY.md](SECURITY.md) 私下报告，不要创建公开 Issue。

## 许可证

PinyinTab 使用 [MIT License](LICENSE)。
