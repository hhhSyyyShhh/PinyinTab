# PinyinTab 项目维护、提交与发布手册

这是一份写给项目维护者的中文 README。以后无论是修 Bug、增加功能、修改文档、更新 GitHub 首页，还是发布新版本，都可以从这里开始。

当前正式仓库：<https://github.com/hhhSyyyShhh/PinyinTab>

当前主分支：`main`

当前发布方式：向 GitHub 推送 `v*` 标签后，由 GitHub Actions 自动测试、构建两个平台的安装包、生成 SHA-256 校验文件并创建 GitHub Release。

---

## 1. 先理解整个项目是怎样发布出去的

完整流程如下：

```text
修改本地文件
    ↓
本地格式化和测试
    ↓
git add + git commit
    ↓
git push origin main
    ↓
GitHub Actions 自动运行 CI
    ↓
准备版本号和 CHANGELOG
    ↓
创建并推送 v0.x.y 标签
    ↓
Release 工作流在 Ubuntu 和 macOS 上分别构建
    ↓
生成两个 tar.gz + 两个 .sha256
    ↓
自动创建 GitHub Release
    ↓
用户从 Release 或在线安装脚本安装
```

这里有三个容易混淆的概念：

- Git commit：一次代码或文档修改记录，例如 `fix: repair online installer`。
- Git tag：给某个 commit 加上固定版本名，例如 `v0.3.1`。
- GitHub Release：GitHub 网站上的正式下载页面，包含版本说明和安装包。

PinyinTab 的版本历史主要由 Git tag 和 GitHub Release 产生，不是靠手工在 README 里写一个版本数字产生的。

---

## 2. 项目文件分别放在哪里

### 2.1 最常修改的文件

| 你想修改的内容 | 文件位置 | 作用 |
|---|---|---|
| 拼音匹配、候选过滤、多级路径等核心逻辑 | `src/lib.rs` | Rust 核心库和单元测试 |
| `ptab` 命令、参数和输出 | `src/main.rs` | 命令行入口 |
| Bash 的 Tab 补全行为 | `shell/pinyintab.bash` | Ubuntu/Linux Bash 集成 |
| Zsh 的 Tab 补全行为 | `shell/pinyintab.zsh` | macOS Zsh 集成 |
| 安装行为 | `install.sh` | 把二进制和 Shell 文件安装到用户目录 |
| 卸载行为 | `uninstall.sh` | 删除安装文件并清理 Shell 配置 |
| 联网下载安装 | `scripts/install-online.sh` | 自动识别平台、下载最新 Release、校验并安装 |
| 从源码安装 | `scripts/install-from-source.sh` | 本地编译并安装 |
| Release 压缩包内容 | `scripts/package-release.sh` | 编译、组装 tar.gz、生成 SHA-256 |
| 项目版本号和 Rust 元数据 | `Cargo.toml` | 包名、版本、仓库地址、最低 Rust 版本 |
| 依赖锁定版本 | `Cargo.lock` | 保证不同机器尽量使用相同依赖 |
| 用户可读的版本历史 | `CHANGELOG.md` | 每个版本新增、修复和变化 |

### 2.2 README、协议和社区文件

| 内容 | 文件位置 |
|---|---|
| 英文项目首页 | `README.md` |
| 中文项目首页 | `README.zh-CN.md` |
| MIT 开源协议 | `LICENSE` |
| 参与贡献说明 | `CONTRIBUTING.md` |
| 安全漏洞报告方式 | `SECURITY.md` |
| Bug Issue 表单 | `.github/ISSUE_TEMPLATE/bug_report.yml` |
| 功能建议表单 | `.github/ISSUE_TEMPLATE/feature_request.yml` |
| Pull Request 模板 | `.github/pull_request_template.md` |
| 本维护与发布手册 | `docs/RELEASE_GUIDE.md` |
| 技术架构 | `docs/ARCHITECTURE.md` |
| 兼容边界 | `docs/COMPATIBILITY.md` |
| Bug 历史 | `docs/BUG_REPORT.md` |
| 技术栈说明 | `docs/技术栈与实现说明.md` |

### 2.3 自动化文件

| 文件位置 | 什么时候触发 | 做什么 |
|---|---|---|
| `.github/workflows/ci.yml` | 推送 `main` 或提交 Pull Request | Rust 测试、格式检查、Clippy、Linux Bash 测试、macOS Zsh 测试 |
| `.github/workflows/release.yml` | 推送名字符合 `v*` 的 tag | 构建双平台安装包并创建 GitHub Release |

不要把 `target/`、`dist/`、`.DS_Store`、临时日志或本地编译产物提交到 GitHub。忽略规则位于 `.gitignore`。

---

## 3. 第一次把项目放到 GitHub 时做了什么

PinyinTab 首次建仓时采用以下配置：

- Repository name：`pinyintab`
- Description：`Type Pinyin, press Tab, get the real Chinese path.`
- Visibility：Public
- 默认分支：`main`
- 没有让 GitHub 自动生成 README、`.gitignore` 或 License，因为本地已经有这些文件
- Remote：`https://github.com/hhhSyyyShhh/PinyinTab.git`

本地初始化的核心命令是：

```bash
git init
git branch -M main
git add .
git commit -m "feat: prepare PinyinTab v0.3.0"
git remote add origin https://github.com/hhhSyyyShhh/PinyinTab.git
git push -u origin main
```

项目里保留了 `scripts/configure-repository.sh`。如果以后把整个项目迁移到另一个 GitHub 用户或组织，可以运行：

```bash
./scripts/configure-repository.sh 新的GitHub用户名
```

它会同步调整中英文 README、`Cargo.toml`、在线安装器和本手册中的仓库所有者。执行后必须检查差异并重新测试，不要不看内容就直接提交。

---

## 4. 每次修改项目的标准流程

### 4.1 开始前同步远程代码

进入项目根目录：

```bash
cd pinyintab
git switch main
git pull --ff-only
git status
```

`git pull --ff-only` 可以避免 Git 在你没有意识到的情况下自动制造合并提交。

较大的修改建议新建分支：

```bash
git switch -c fix/简短问题名
```

例如：

```bash
git switch -c fix/mixed-pinyin-completion
```

### 4.2 修改后先查看差异

```bash
git status --short
git diff
```

确认没有 API Key、Token、服务器密码、私人路径、录屏隐私信息或无关文件。

### 4.3 本地检查

通用 Rust 检查：

```bash
cargo fmt --all
cargo test --locked --all-targets
cargo clippy --locked --all-targets -- -D warnings
cargo build --release --locked
```

Shell 语法检查：

```bash
bash -n install.sh uninstall.sh shell/pinyintab.bash scripts/*.sh
zsh -n shell/pinyintab.zsh scripts/test-macos.zsh
```

补全回归测试：

```bash
./scripts/test-completion.sh
./scripts/test-macos.zsh
```

在 Linux 上没有 Zsh 时，不要强行执行 Zsh 测试；GitHub Actions 会在 macOS Runner 上执行。Linux 重点运行 Bash 测试，macOS 重点运行 Zsh 测试。

### 4.4 提交修改

尽量只添加本次修改涉及的文件：

```bash
git add src/lib.rs shell/pinyintab.bash docs/BUG_REPORT.md
git diff --cached
git commit -m "fix: preserve mixed pinyin refinement"
```

常见提交前缀：

| 前缀 | 用途 | 示例 |
|---|---|---|
| `feat:` | 新功能 | `feat: add fish completion prototype` |
| `fix:` | Bug 修复 | `fix: preserve suffix after ambiguous match` |
| `docs:` | 只改文档 | `docs: add maintainer release guide` |
| `test:` | 测试变化 | `test: cover nested mixed paths` |
| `refactor:` | 不改变功能的代码整理 | `refactor: split candidate filtering` |
| `chore:` | 发布、依赖、自动化等维护 | `chore: release v0.3.1` |

### 4.5 推送普通修改

如果直接在 `main` 修改：

```bash
git push origin main
```

如果使用功能分支：

```bash
git push -u origin fix/简短问题名
```

然后在 GitHub 创建 Pull Request。GitHub 会读取 `.github/pull_request_template.md`，并自动运行 CI。

推送成功不等于修改已经可靠。还要进入：

```text
GitHub 仓库 → Actions → CI
```

确认 Ubuntu、macOS 和 Rust quality 三部分全部为绿色。

---

## 5. 什么时候应该修改版本号

项目使用语义化版本：

```text
MAJOR.MINOR.PATCH
  0  .  3  .  1
```

- PATCH：兼容的 Bug 修复，例如 `0.3.0 → 0.3.1`。
- MINOR：兼容的新功能、新 Shell 或新平台，例如 `0.3.1 → 0.4.0`。
- MAJOR：1.0 以后出现不兼容的配置、命令或协议变化时增加。

以下修改通常不需要立即发布版本：

- 修正错别字。
- 完善内部说明。
- 尚未完成、还不能交给用户的实验代码。

以下修改通常应该发布新版本：

- 修复用户实际能遇到的补全 Bug。
- 改变安装器或卸载器。
- 新增命令、新平台或 Shell。
- 修改 Release 包内的文件。
- 修改会影响用户使用方式的默认行为。

---

## 6. 发布新版本前要修改哪些文件

假设准备从 `0.3.0` 发布到 `0.3.1`。

### 6.1 修改 `Cargo.toml`

```toml
[package]
version = "0.3.1"
```

修改后运行一次不带 `--locked` 的 Cargo 命令，让根包版本同步到 `Cargo.lock`：

```bash
cargo check
```

然后确认：

```bash
rg 'version = "0.3.1"' Cargo.toml Cargo.lock
```

### 6.2 修改 `CHANGELOG.md`

把已经完成的内容从 `[Unreleased]` 移到正式版本标题下：

```markdown
## [0.3.1] - 2026-07-19

### Fixed

- Fixed online installation for the configured GitHub repository.
```

`CHANGELOG.md` 应写用户能理解的变化，不要只复制晦涩的 commit 信息。

### 6.3 检查 README 和兼容文档

如果支持平台、安装命令、最低版本或使用方式发生变化，需要同步检查：

- `README.md`
- `README.zh-CN.md`
- `docs/COMPATIBILITY.md`
- `docs/ARCHITECTURE.md`
- `SECURITY.md`

### 6.4 完整测试

```bash
cargo fmt --all
cargo test --locked --all-targets
cargo clippy --locked --all-targets -- -D warnings
cargo build --release --locked
./scripts/test-completion.sh
./scripts/test-macos.zsh
```

### 6.5 提交发布准备

```bash
git add Cargo.toml Cargo.lock CHANGELOG.md README.md README.zh-CN.md
git diff --cached
git commit -m "chore: release v0.3.1"
git push origin main
```

先等待 `main` 的 CI 全绿，再创建标签。不要在 CI 失败时继续正式发布。

---

## 7. 创建 Git tag 并自动发布

确认当前分支干净、版本正确：

```bash
git status
git log -1 --oneline
rg '^version = ' Cargo.toml
```

创建带注释的标签：

```bash
git tag -a v0.3.1 -m "PinyinTab v0.3.1"
git show --no-patch v0.3.1
git push origin v0.3.1
```

推送 `v0.3.1` 后，`.github/workflows/release.yml` 会自动执行：

```text
v0.3.1 tag
    ├── Ubuntu 22.04 x86_64 Runner
    │     ├── cargo test
    │     ├── 编译 x86_64-unknown-linux-gnu
    │     └── 生成 Linux tar.gz 和 SHA-256
    ├── macOS 15 Apple Silicon Runner
    │     ├── cargo test
    │     ├── 编译 aarch64-apple-darwin
    │     └── 生成 macOS tar.gz 和 SHA-256
    └── Publish job
          ├── 下载两个构建任务的产物
          └── 使用 gh release create 创建 GitHub Release
```

最终文件名应该是：

```text
pinyintab-v0.3.1-x86_64-unknown-linux-gnu.tar.gz
pinyintab-v0.3.1-x86_64-unknown-linux-gnu.tar.gz.sha256
pinyintab-v0.3.1-aarch64-apple-darwin.tar.gz
pinyintab-v0.3.1-aarch64-apple-darwin.tar.gz.sha256
```

版本包的具体内容由 `scripts/package-release.sh` 决定。目前包括：

- `bin/ptab`
- `shell/pinyintab.bash`
- `shell/pinyintab.zsh`
- `install.sh`
- `uninstall.sh`
- 中英文 README
- `CHANGELOG.md`
- `LICENSE`

如果将来增加必须随安装包分发的文件，需要同时修改 `scripts/package-release.sh`，否则文件虽然在 GitHub 源码中存在，却不会进入 Release 压缩包。

---

## 8. 发布后必须验证什么

不要只看 Release 页面出现了版本号。至少检查以下项目：

### 8.1 检查 GitHub 页面

- `Actions → CI` 为绿色。
- `Actions → Release` 为绿色。
- Release 标签和 `Cargo.toml` 版本一致。
- 两个 `.tar.gz` 和两个 `.sha256` 都存在。
- Release 不是 Draft，也不是误标的 Pre-release。

### 8.2 验证校验值和包内容

下载压缩包和对应的 `.sha256`：

```bash
shasum -a 256 -c pinyintab-v0.3.1-aarch64-apple-darwin.tar.gz.sha256
tar -tzf pinyintab-v0.3.1-aarch64-apple-darwin.tar.gz
```

Linux 通常也可以使用：

```bash
sha256sum -c pinyintab-v0.3.1-x86_64-unknown-linux-gnu.tar.gz.sha256
```

### 8.3 在真实系统安装

分别在 Ubuntu x86_64 和 Apple Silicon Mac 上验证：

```bash
./install.sh
ptab status
ptab doctor
```

然后测试：

1. `cd` 单层和多级中文目录。
2. Python、Java、Julia 等中文文件名。
3. 同前缀候选连续输入拼音缩小范围。
4. 中文加拼音的混合补全。
5. 空格、括号和特殊字符路径。
6. `ptab off` 后原 Shell 补全能恢复。
7. `./uninstall.sh` 能清理安装。

### 8.4 验证在线安装器

在线安装入口位于 `scripts/install-online.sh`。它会：

1. 识别 `Linux/x86_64` 或 `Darwin/arm64`。
2. 查询 GitHub 最新 Release。
3. 下载对应压缩包和 SHA-256。
4. 校验文件。
5. 解压并运行包内的 `install.sh`。

README 中公开的一键安装命令必须在新机器上实际测试，不能只测试手动下载压缩包。

---

## 9. README 首页、徽章和 Star History 曲线在哪里修改

项目首页由两个 Markdown 文件组成：

- 英文：`README.md`
- 中文：`README.zh-CN.md`

普通 README 不需要额外 HTML。居中标题和徽章使用了少量 HTML 标签，但主要内容仍是标准 Markdown。

### 9.1 顶部徽章

README 顶部目前包括：

- CI 状态徽章。
- 最新 Release 版本徽章。
- MIT License 徽章。
- 支持平台徽章。

修改仓库名、工作流文件名或平台范围后，要同步修改徽章 URL。

### 9.2 Star History 曲线

你提到的“start 曲线”准确名称是 **Star History**，它表示 GitHub Star 数量随时间的变化。

当前代码在两个 README 的 `## Star History` 小节：

```markdown
[![Star History Chart](https://api.star-history.com/svg?repos=hhhSyyyShhh/PinyinTab&type=Date&legend=top-left)](https://www.star-history.com/?repos=hhhSyyyShhh%2FPinyinTab&type=date&legend=top-left)
```

它从 GitHub 的公开 Star 数据自动生成，不需要自己写后端、HTML 或数据库。新仓库没有 Star 时曲线为空是正常现象。

如果仓库改名或迁移所有者，需要修改上面两处 URL，或运行：

```bash
./scripts/configure-repository.sh 新的GitHub用户名
```

不要伪造 Star 数据，也不要把 Star 数量写成功能质量保证。

### 9.3 演示视频或 GIF

建议把体积较小的演示 GIF 放在：

```text
docs/assets/demo.gif
```

然后在 README 中引用：

```markdown
![PinyinTab demo](docs/assets/demo.gif)
```

较大的 MP4 不建议直接反复提交到 Git 历史。可以上传到 GitHub Release、GitHub Issue 附件或稳定的视频平台，再在 README 中放链接。

录屏发布前必须遮盖：

- 用户名和真实姓名。
- 服务器 IP、域名和 SSH 信息。
- 绝对私人目录。
- Token、环境变量和终端历史。
- 桌面通知和其他项目内容。

---

## 10. MIT 开源协议是什么，在哪里修改

开源协议文件位于根目录：

```text
LICENSE
```

PinyinTab 当前使用 MIT License。它允许别人使用、复制、修改、合并、发布、再分发和商业使用代码，但要求保留版权声明和协议文本，同时软件按“原样”提供，不承诺担保。

README 中的许可证入口位于：

- 顶部 `License: MIT` 徽章。
- 底部 `## 开源许可证` 小节。
- `Cargo.toml` 的 `license = "MIT"`。

如果以后真的更换协议，至少要同步修改：

1. `LICENSE`
2. `Cargo.toml`
3. `README.md`
4. `README.zh-CN.md`
5. Release 包内容和相关说明

不要随便删除第三方代码原本携带的版权和协议。引入依赖时，也要确认其协议与项目分发方式兼容。

---

## 11. GitHub 上还有哪些内容需要维护

### 11.1 About 和 Topics

在仓库首页右侧 About 区域可以维护 Description、Website 和 Topics。

建议 Topics：

```text
pinyin shell completion bash zsh rust linux macos cli chinese
```

### 11.2 Issues 和 Pull Request

Issue 和 PR 文件位于：

```text
.github/ISSUE_TEMPLATE/bug_report.yml
.github/ISSUE_TEMPLATE/feature_request.yml
.github/pull_request_template.md
```

新增诊断信息时，应让 Bug 表单收集 `ptab doctor`、操作系统、架构、Shell 版本和最小复现，但不要要求用户公开 Token、服务器地址或敏感绝对路径。

### 11.3 分支保护

项目稳定后，建议在 `Settings → Branches` 或 `Settings → Rules` 为 `main` 设置：

- 合并前必须通过 Pull Request。
- 必须通过 CI。
- 禁止直接 force push。
- 禁止删除 `main`。

### 11.4 安全设置

建议开启 Dependabot alerts、Secret scanning 和 Private vulnerability reporting。

CI 权限保持最小化：`.github/workflows/ci.yml` 只有 `contents: read`；只有 `.github/workflows/release.yml` 创建 Release 时使用 `contents: write`。

---

## 12. 如何增加新的平台或架构

不能只在 README 表格里增加一行。正式支持一个新平台至少要完成：

1. 确认 Rust target。
2. 修改 `.github/workflows/release.yml` 的 build matrix。
3. 修改 `scripts/package-release.sh` 允许该 target。
4. 修改 `scripts/install-online.sh` 的系统识别。
5. 增加相应 Shell 集成或兼容处理。
6. 增加 CI Runner 和测试脚本。
7. 修改中英文 README 和 `docs/COMPATIBILITY.md`。
8. 在真实机器上安装、补全、关闭和卸载测试。

例如支持 Linux ARM64 时，不能因为 Rust 能编译 `aarch64-unknown-linux-gnu` 就直接写“正式支持”。还需要确认 Runner、glibc、Shell 行为和真实机器测试。

---

## 13. GitHub Actions 失败时怎样排查

进入：

```text
GitHub 仓库 → Actions → 失败的工作流 → 失败的 Job → 展开红色步骤
```

先找第一条真正的错误，不要只看最后一行 `Process completed with exit code 1`。

| 现象 | 常见原因 | 处理位置 |
|---|---|---|
| `zsh: command not found` | 在 Linux Runner 上误跑 Zsh | `.github/workflows/ci.yml`，按 `runner.os` 加条件 |
| `not a git repository` | 发布 Job 没有 checkout | `.github/workflows/release.yml` 增加 `actions/checkout` |
| 找不到 `dist/*.tar.gz` | 打包脚本失败或 target 不允许 | `scripts/package-release.sh` |
| `Cargo.lock needs to be updated` | 改了 `Cargo.toml` 但没更新锁文件 | 运行 `cargo check` 并提交 `Cargo.lock` |
| Clippy 失败 | Rust 警告被当作错误 | 按日志修改 Rust 代码 |
| 在线安装找不到 Release | 没有正式 Release、仓库地址错误或平台不支持 | `scripts/install-online.sh` 和 Release 页面 |
| Release 没有写权限 | Workflow token 权限不足 | `release.yml` 的 `permissions` 和仓库 Actions 设置 |

修改工作流后，先推送 `main` 让 CI 验证。不要反复重写已经公开并有人使用的版本标签。

如果标签已经公开发布，发现问题时应修复后增加 PATCH 版本，例如从 `v0.3.1` 发布 `v0.3.2`。只有在标签刚创建、Release 完全失败、确定无人下载时，才可能考虑删除并重建标签；这不是日常推荐流程。

---

## 14. 常用 Git 命令速查

```bash
git status --short --branch             # 当前状态
git diff                                # 未暂存差异
git diff --cached                       # 准备提交的差异
git log --oneline --decorate -10        # 最近记录
git switch main                         # 切换 main
git pull --ff-only                      # 同步 main
git switch -c feat/功能名               # 新建分支
git add 文件1 文件2                     # 添加指定文件
git commit -m "feat: describe change"  # 提交
git push origin main                    # 推送 main
git remote -v                           # 远程地址
git tag --list                          # 标签列表
git tag -a v0.3.1 -m "PinyinTab v0.3.1"
git push origin v0.3.1                  # 触发发布
```

不要在不理解后果时使用 `git reset --hard`、`git push --force` 或 `git clean -fd`，它们可能丢失工作或改写远程历史。

---

## 15. 普通修改检查清单

- [ ] 已同步最新 `main`。
- [ ] 修改范围清楚，没有混入无关文件。
- [ ] 没有提交密码、Token、IP 或隐私路径。
- [ ] Rust 格式化、测试和 Clippy 通过。
- [ ] 修改 Bash 后执行 Bash 测试。
- [ ] 修改 Zsh 后执行 macOS/Zsh 测试。
- [ ] 新 Bug 有对应回归测试。
- [ ] 用户行为变化已更新中英文 README 或兼容文档。
- [ ] `git diff --cached` 已人工检查。
- [ ] 推送后 GitHub CI 全绿。

---

## 16. 正式发布检查清单

- [ ] `Cargo.toml` 版本正确。
- [ ] `Cargo.lock` 已同步并提交。
- [ ] `CHANGELOG.md` 有新版本和日期。
- [ ] README 的平台、安装和使用说明仍准确。
- [ ] 本地完整测试通过。
- [ ] `main` 已推送且 CI 全绿。
- [ ] tag 名、Cargo 版本和 Changelog 版本一致。
- [ ] Release 工作流全绿。
- [ ] 两个 tar.gz 和两个 SHA-256 文件存在。
- [ ] 两个平台的校验值通过。
- [ ] Ubuntu x86_64 真实安装测试通过。
- [ ] Apple Silicon macOS 真实安装测试通过。
- [ ] 在线安装器测试通过。
- [ ] 演示图片或视频没有隐私信息。
- [ ] Release 页面不是 Draft 或错误的 Pre-release。

---

## 17. 最短发布流程

熟悉全部细节以后，可以用下面这段速查，但不能跳过测试和人工检查：

```bash
# 修改 Cargo.toml、CHANGELOG.md 和相关文档后更新锁文件
cargo check

# 测试
cargo fmt --all
cargo test --locked --all-targets
cargo clippy --locked --all-targets -- -D warnings

# 提交并推送 main
git add Cargo.toml Cargo.lock CHANGELOG.md README.md README.zh-CN.md
git diff --cached
git commit -m "chore: release v0.3.1"
git push origin main

# 等待 CI 全绿后发布
git tag -a v0.3.1 -m "PinyinTab v0.3.1"
git push origin v0.3.1
```

发布完成后，进入 <https://github.com/hhhSyyyShhh/PinyinTab/releases> 检查安装包，并在真实系统重新走一遍安装、补全、关闭和卸载流程。
