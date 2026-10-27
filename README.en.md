<div align="center">

# PinyinTab

**Type the sound. Tab the path.**

Native Pinyin-aware path completion for Bash and Zsh.

中文路径拼音补全：输入拼音，按 Tab，得到真实中文路径。 | Type Pinyin, press Tab, get the real Chinese path.

[简体中文](README.md) · [Install](#installation) · [Usage](#usage) · [Language selection](#language-selection) · [Compatibility](#compatibility)

[![CI](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml/badge.svg)](https://github.com/hhhSyyyShhh/PinyinTab/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hhhSyyyShhh/PinyinTab?display_name=tag)](https://github.com/hhhSyyyShhh/PinyinTab/releases)
[![Stars](https://img.shields.io/github/stars/hhhSyyyShhh/PinyinTab?style=flat)](https://github.com/hhhSyyyShhh/PinyinTab/stargazers)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

PinyinTab lets you type Pinyin for a Chinese filename or directory and press <kbd>Tab</kbd> to insert its real path. It does not rename files, mount a virtual filesystem, or modify interpreters.

[![PinyinTab terminal demo](assets/demo.gif)](assets/demo.mp4)

> This is an earlier basic-completion recording, not a v0.6.0 shortcut test.
> See the [four current selection operations](#language-selection) below.

```text
python3 jiujiuchengfabiao.py<Tab>
        ↓
python3 九九乘法表.py
```

## Features

- Full Pinyin, initials, literal Chinese prefixes, and mixed Chinese + Pinyin refinement.
- Multi-level completion through Pinyin parent directories.
- Complete real names take precedence over prefix/Pinyin expansion.
- Tab prefers non-Han names; Control+X then c/e explicitly selects either group.
- Complete Chinese names can select existing full-Pinyin/initial counterparts without a previous Tab query.
- Multiple candidates within a group still require refinement, never guessing.
- Command-aware directory, file, and Java class completion.
- Reversible `ptab on` / `ptab off` integration that restores previous completers.
- One Rust core shared by Linux Bash and macOS Zsh.
- No daemon, FUSE mount, or network request during completion.

## Installation

### Prebuilt release

The installer is per-user, requires no `sudo`, and does not require Rust:

```bash
curl --proto '=https' --tlsv1.2 -fL --connect-timeout 10 --max-time 60 \
  https://github.com/hhhSyyyShhh/PinyinTab/releases/latest/download/install-online.sh \
  -o install-online.sh
```

Stop if curl reports an error. Downloading the script is not installation; it
must also fetch the Release archive and checksum. Then check syntax (not a
security audit), inspect the script if desired, and run installation separately:

```bash
bash -n install-online.sh
```

```bash
bash install-online.sh
```

The normal installer loads the `ptab` command but leaves completion disabled. Restart the terminal and enable it for the current Shell when needed:

```bash
ptab on
```

In the new terminal, `ptab version` should report `PinyinTab 0.6.0`. If the
command is unavailable after a successful install, source
`~/.local/share/pinyintab/pinyintab.zsh` (Zsh) or `pinyintab.bash` (Bash), then
run `ptab on`. The [Chinese quick start](README.md#安装) includes separate
platform-specific offline installation and network troubleshooting steps.

To opt in to automatic activation in every new Shell, install with:

```bash
bash install-online.sh --enable-on-startup
```

If GitHub is unavailable from your network, download the matching archive and `.sha256` file from [Releases](https://github.com/hhhSyyyShhh/PinyinTab/releases), verify it, extract it, and run `./install.sh` with the same optional flag.

An HTTP 403 response with `API rate limit exceeded` means the current network's
anonymous GitHub API quota is exhausted. Wait for reset or use the documented
manual installation; do not paste account tokens into public issue reports.

### From source

Rust 1.66 or newer is required only for a source build:

```bash
git clone https://github.com/hhhSyyyShhh/PinyinTab.git
cd PinyinTab
./scripts/install-from-source.sh
```

### Update

Starting with v0.6.0, run `ptab update`, then reopen the terminal and run
`ptab version` and `ptab on`. Older versions must first be upgraded once using
the installer. Updates verify SHA-256 and the staged binary, never downgrade,
and attempt rollback if replacement checks fail. Startup configuration and
personal files are preserved. Temporary downloads and successful transaction
backups are removed, not manually downloaded archives. Recovery failures retain
backups and report their location. GitHub access is still required.

### Oh My Zsh

After installing the binary, clone the repository as an Oh My Zsh custom plugin:

```zsh
git clone https://github.com/hhhSyyyShhh/PinyinTab.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/pinyintab"
```

Add `pinyintab` to the `plugins=(...)` list in `~/.zshrc`, then restart Zsh. Selecting the plugin is an explicit opt-in, so this entry point enables completion when Oh My Zsh loads it. The repository also exposes `pinyintab.plugin.zsh` for compatible Zsh plugin managers.

### Uninstall

Run this from a source checkout or extracted release:

```bash
bash "$HOME/.local/share/pinyintab/uninstall.sh"
```

The uninstaller removes PinyinTab's marked Shell configuration block and files under `~/.local`. It preserves the configuration backup created during installation.
Downloaded archives and manually extracted directories are not removed automatically. Remove them separately after checking for personal files, and restart the terminal to clear any loaded shell function.

## Language selection

Assume the only entries matching `cs1` are `cs1.py` and `测试1.py`:

| Action | Result |
|---|---|
| Type `vim cs1`, press Tab | `vim cs1.py` |
| Immediately press Control+X, release, then c | `vim 测试1.py` |
| Press Control+X, release, then e | `vim cs1.py` |
| Type `vim cs1`, then Control+X and c without Tab | `vim 测试1.py` |

On Mac use **Control**, not Command. These are sequential keys, not bare
Control+C/E, whose native functions are preserved. Selection applies to one
completion, not future commands. Changed text or cursor invalidates the old
query. A space starts a new argument; empty queries list both non-hidden groups.
Multiple matches require refinement. Names with Han characters (including
mixed names) are Chinese; “English” means names without Han characters, tested
on the final component, not its parent directory. Exact real names stay intact
under ordinary Tab; explicit Chinese selection can bypass an English collision.
This affects the shell only, not Vim/Neovim insert-mode completion.

At the end of `vim 测试1.py`, Control+X then e also finds an existing `cs1.py`
without a Tab snapshot. Complete-name switching preserves numbers, extensions
and parent paths: it will not select `cs2.py`. Multiple counterparts such as
`cs1.py` and `ceshi1.py` are listed without replacing the query; no match leaves
it unchanged. These are distinct existing files, not renamed files or copies.

## Usage

```bash
ptab on       # enable in the current shell
ptab off      # restore the previous completers
ptab status   # show shell integration state
ptab doctor   # show version, platform, architecture, shell, and state
ptab version
ptab update   # update an installed release, then reopen the terminal
ptab --help   # commands, options, examples, and scope notes
ptab help zh  # Chinese help
```

Help does not change completion state. Use `ptab help advanced` for diagnostic
interfaces. The `on/off/status` commands require the integration loaded in the
current shell; a standalone child process cannot change its parent shell.

Use normal commands and press <kbd>Tab</kbd> on the Pinyin path:

```bash
cd ceshimulu<Tab>
./yunxingchengxu<Tab>
cat xiangmushuoming.md<Tab>
python3 ceshi.py<Tab>
julia chengfakoujuebiao.jl<Tab>
javac chengfakoujuebiao.java<Tab>
java chengfakoujuebiao<Tab>
```

After completion, the command line contains the real Chinese name. Pinyin is a query used at Tab time, not a virtual filename that remains valid after Enter.

Command-position completion (`./`, `../`, absolute paths) returns executable files and navigable directories. Files still need execute permission and a valid binary format or script shebang; Tab never runs them. Directory candidates remain available for entering paths one component at a time. See the [tested command contexts](docs/COMPATIBILITY.md#v041-命令上下文回归范围).

## Compatibility

| Platform | Architecture | Shell | Release target | Status |
|---|---|---|---|---|
| Ubuntu 22.04 / 24.04 | x86_64 / AMD64 | Bash | `x86_64-unknown-linux-gnu` | Tested |
| CentOS Stream 9 | x86_64 / AMD64 | Bash | `x86_64-unknown-linux-gnu` | Tested |
| macOS 14+ | Apple Silicon | Zsh | `aarch64-apple-darwin` | Tested |
| Other glibc 2.34+ Linux | x86_64 / AMD64 | Bash or Zsh | Linux package | Expected, not guaranteed |
| Alpine/musl, Linux ARM64, Intel macOS, Windows | — | — | — | Not currently released |

The Linux archive requires glibc 2.34 or newer. End-of-life CentOS Linux 7/8 and CentOS Stream 8 are not supported. PinyinTab targets ordinary local path arguments; remote `host:path` syntax, URLs, here-documents, application-specific option grammars, and third-party completers may need dedicated integration. See the [compatibility boundary](docs/COMPATIBILITY.md).

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
