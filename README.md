<div align="center">

# PinyinTab

**Type the sound. Tab the path.**

Type Pinyin in Bash or Zsh, press <kbd>Tab</kbd>, and get the real Chinese path.

[简体中文](README.zh-CN.md) · [Installation](#installation) · [Compatibility](#compatibility) · [Documentation](#documentation)

[![CI](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml/badge.svg)](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hhhSyyyShhh/PinyinTab?display_name=tag)](https://github.com/hhhSyyyShhh/PinyinTab/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Linux%20x86__64%20%7C%20macOS%20arm64-lightgrey)](#compatibility)

</div>

PinyinTab is a native shell-completion plugin for Chinese file and directory names. It does not rename files, create aliases on disk, mount a virtual filesystem, or modify interpreters. The shell replaces the typed Pinyin with the real path before `cd`, Python, Java, Julia, or another command runs.

```text
python3 jiujiuchengfabiao.py<Tab>
        ↓
python3 九九乘法表.py
```

Nested paths and refinement after an ambiguous match are supported:

```text
cd ceshimulu/neibuwenjiant<Tab>     → cd 测试目录/内部文件夹/
python3 jiujiu<Tab>                 → several 九九… candidates
python3 九九cf<Tab>                 → python3 九九乘法表.py
```

## Why PinyinTab?

- Native <kbd>Tab</kbd> completion: no fuzzy-finder screen and no virtual directory.
- Full Pinyin, initials, real Chinese prefixes, and mixed Chinese + Pinyin refinement.
- Multi-level path resolution, including Pinyin parent directories.
- Command-aware candidates for directories, files, and Java class names.
- Reversible `ptab on` / `ptab off` integration that restores previous completers.
- One Rust core shared by Bash on Linux and Zsh on macOS.
- No daemon, no FUSE, and no network access during completion.

## Installation

### Install a prebuilt release

The installer needs no Rust toolchain and installs only for the current user.

```bash
curl --proto '=https' --tlsv1.2 -fsSLO \
  https://raw.githubusercontent.com/hhhSyyyShhh/PinyinTab/main/scripts/install-online.sh
less install-online.sh
bash install-online.sh
```

Restart the terminal, or reload the shell configuration shown by the installer. PinyinTab starts automatically in new terminals.

You can also download the matching archive from [GitHub Releases](https://github.com/hhhSyyyShhh/PinyinTab/releases), verify its `.sha256` file, extract it, and run:

```bash
./install.sh
```

### Install from source

Rust 1.66 or newer is required only for a source installation:

```bash
git clone https://github.com/hhhSyyyShhh/PinyinTab.git
cd pinyintab
./scripts/install-from-source.sh
```

### Uninstall

From a release archive or source checkout:

```bash
./uninstall.sh
```

The uninstaller removes the marked PinyinTab block from `.bashrc` and `.zshrc`, plus files installed under `~/.local`. It does not delete the backup created during installation.

## Usage

```bash
ptab on       # enable completion in this shell
ptab off      # restore the previous shell completers
ptab status   # show current shell state
ptab doctor   # show version, platform, architecture, shell, and state
ptab version
```

Use ordinary commands after activation:

```bash
cd ceshimulu<Tab>
cat xiangmushuoming.md<Tab>
python3 ceshi.py<Tab>
julia chengfakoujuebiao.jl<Tab>
javac chengfakoujuebiao.java<Tab>
java chengfakoujuebiao<Tab>
```

The command line contains the real Chinese name after completion. Pinyin is an input query, not a filename that remains valid after pressing Enter.

## Compatibility

Prebuilt v0.3 releases intentionally cover two targets first:

| Platform | Architecture | Shell | Release target | Status |
|---|---|---|---|---|
| Ubuntu Linux 22.04+ | x86_64 / AMD64 | Bash | `x86_64-unknown-linux-gnu` | Supported and tested |
| macOS 14+ | Apple Silicon M1 or newer | Zsh | `aarch64-apple-darwin` | Supported and tested |
| Other glibc Linux distributions | x86_64 / AMD64 | Bash or Zsh | same Linux binary | Expected, not yet guaranteed |
| Linux ARM64 | arm64 | Bash or Zsh | — | Not released yet |
| Intel macOS | x86_64 | Zsh | — | Not released yet |
| Windows | x86_64 / arm64 | PowerShell | — | Roadmap |

The Linux binary is not automatically universal across every Linux system. It depends on the GNU/glibc target; Alpine/musl, very old glibc systems, and non-x86_64 machines need separate builds.

PinyinTab handles ordinary local path arguments. Remote `host:path` syntax, URLs, here-documents, program-specific option grammars, and third-party completers can require dedicated integration. See [Compatibility Boundary](docs/COMPATIBILITY.md).

## How it works

```text
typed Pinyin
    ↓
Bash/Zsh identifies a path argument
    ↓
ptab scans one directory level and generates Pinyin candidates
    ↓
the shell inserts the real Chinese path
    ↓
cd / Python / Java / Julia / cat receives a normal path
```

PinyinTab interacts with interpreters only indirectly: it completes the path before the interpreter process starts. See [Architecture](docs/ARCHITECTURE.md) for the component and trust boundaries.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Compatibility boundary](docs/COMPATIBILITY.md)
- [Maintainer, Git, README, Star History, and release guide (Chinese)](docs/RELEASE_GUIDE.md)
- [Competitive analysis and common criteria](docs/COMPETITOR_ANALYSIS.md)
- [Bug history and regression coverage](docs/BUG_REPORT.md)
- [Technical stack introduction (Chinese)](docs/技术栈与实现说明.md)
- [Linux deployment notes (Chinese)](docs/Linux版本部署与测试.md)

## Development

```bash
cargo test --locked
cargo build --release --locked
./scripts/test-completion.sh    # Bash
./scripts/test-macos.zsh       # Zsh on macOS
```

The `demo-source` directory contains Chinese-named examples for Python, Java, Julia, JavaScript, Ruby, Perl, C, Rust, Swift, and Bash.

## Roadmap

- [x] Bash and Zsh native completion
- [x] Full Pinyin, initials, mixed refinement, and nested paths
- [x] Linux x86_64 and macOS arm64 release packaging
- [ ] More polyphonic phrase overrides and configurable dictionaries
- [ ] Fish integration
- [ ] Linux arm64 and Intel macOS builds
- [ ] Windows PowerShell prototype

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=hhhSyyyShhh/PinyinTab&type=Date)](https://star-history.com/#hhhSyyyShhh/PinyinTab&Date)

The chart becomes active after the repository owner placeholder is configured and the public GitHub repository exists.

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Please report security-sensitive path disclosure or shell-injection concerns according to [SECURITY.md](SECURITY.md), not through a public issue.

## License

PinyinTab is available under the [MIT License](LICENSE).
