<div align="center">

# PinyinTab

**Type the sound. Tab the path.**

Native Pinyin-aware path completion for Bash and Zsh.

[简体中文](README.zh-CN.md) · [Install](#installation) · [Usage](#usage) · [Compatibility](#compatibility)

[![CI](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml/badge.svg)](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hhhSyyyShhh/PinyinTab?display_name=tag)](https://github.com/hhhSyyyShhh/PinyinTab/releases)
[![Stars](https://img.shields.io/github/stars/hhhSyyyShhh/PinyinTab?style=flat)](https://github.com/hhhSyyyShhh/PinyinTab/stargazers)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

PinyinTab lets you type Pinyin for a Chinese filename or directory and press <kbd>Tab</kbd> to insert its real path. It does not rename files, mount a virtual filesystem, or modify interpreters.

[![PinyinTab terminal demo](assets/demo.gif)](assets/demo.mp4)

```text
python3 jiujiuchengfabiao.py<Tab>
        ↓
python3 九九乘法表.py
```

## Features

- Full Pinyin, initials, literal Chinese prefixes, and mixed Chinese + Pinyin refinement.
- Multi-level completion through Pinyin parent directories.
- Ambiguous candidates remain visible while further input narrows the result.
- Command-aware directory, file, and Java class completion.
- Reversible `ptab on` / `ptab off` integration that restores previous completers.
- One Rust core shared by Linux Bash and macOS Zsh.
- No daemon, FUSE mount, or network request during completion.

## Installation

### Prebuilt release

The installer is per-user, requires no `sudo`, and does not require Rust:

```bash
curl --proto '=https' --tlsv1.2 -fL \
  https://github.com/hhhSyyyShhh/PinyinTab/releases/latest/download/install-online.sh \
  -o install-online.sh
less install-online.sh
bash install-online.sh
```

Restart the terminal after installation. If GitHub is unavailable from your network, download the matching archive and `.sha256` file from [Releases](https://github.com/hhhSyyyShhh/PinyinTab/releases), verify it, extract it, and run `./install.sh`.

### From source

Rust 1.66 or newer is required only for a source build:

```bash
git clone https://github.com/hhhSyyyShhh/PinyinTab.git
cd PinyinTab
./scripts/install-from-source.sh
```

### Uninstall

Run this from a source checkout or extracted release:

```bash
./uninstall.sh
```

The uninstaller removes PinyinTab's marked Shell configuration block and files under `~/.local`. It preserves the configuration backup created during installation.

## Usage

```bash
ptab on       # enable in the current shell
ptab off      # restore the previous completers
ptab status   # show shell integration state
ptab doctor   # show version, platform, architecture, shell, and state
ptab version
```

Use normal commands and press <kbd>Tab</kbd> on the Pinyin path:

```bash
cd ceshimulu<Tab>
cat xiangmushuoming.md<Tab>
python3 ceshi.py<Tab>
julia chengfakoujuebiao.jl<Tab>
javac chengfakoujuebiao.java<Tab>
java chengfakoujuebiao<Tab>
```

After completion, the command line contains the real Chinese name. Pinyin is a query used at Tab time, not a virtual filename that remains valid after Enter.

## Compatibility

| Platform | Architecture | Shell | Release target | Status |
|---|---|---|---|---|
| Ubuntu 22.04+ | x86_64 / AMD64 | Bash | `x86_64-unknown-linux-gnu` | Tested |
| macOS 14+ | Apple Silicon | Zsh | `aarch64-apple-darwin` | Tested |
| Other glibc Linux | x86_64 / AMD64 | Bash or Zsh | Linux package | Expected, not guaranteed |
| Alpine/musl, Linux ARM64, Intel macOS, Windows | — | — | — | Not currently released |

PinyinTab targets ordinary local path arguments. Remote `host:path` syntax, URLs, here-documents, application-specific option grammars, and third-party completers may need dedicated integration. See the [compatibility boundary](docs/COMPATIBILITY.md).

## How it works

```text
Pinyin typed in Bash/Zsh
          ↓
Shell selects the current path argument and command context
          ↓
Rust scans one directory level and matches real/full/initial aliases
          ↓
Shell displays or inserts the real Chinese path
          ↓
cd, Python, Java, Julia, or another command runs normally
```

The completion engine resolves parent components one level at a time and inserts a path only when it can do so safely. See [architecture](docs/ARCHITECTURE.md) for module and trust boundaries.

## Development

```bash
cargo fmt --all -- --check
cargo test --locked --all-targets
cargo clippy --locked --all-targets -- -D warnings
cargo build --release --locked
./scripts/test-completion.sh
./scripts/test-macos.zsh
```

CI runs Rust and Shell tests on Ubuntu and macOS, checks formatting and Clippy, and enforces a 70% Rust line-coverage floor. Chinese-named examples for Python, Java, Julia, JavaScript, Ruby, Perl, C, Rust, Swift, and Bash are available in `demo-source`.

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. User-visible changes belong in [CHANGELOG.md](CHANGELOG.md). Report potential path disclosure or Shell-injection vulnerabilities according to [SECURITY.md](SECURITY.md), not in a public issue.

## License

PinyinTab is released under the [MIT License](LICENSE).
