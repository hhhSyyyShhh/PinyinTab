# PinyinTab GitHub 建仓与发布指南

这份文档用于把当前本地项目变成可维护的公开 GitHub 项目，并解释版本号、Release 历史、双平台安装包和 Star History 是怎样产生的。

## 1. 发布前配置仓库所有者

README 和在线安装器暂时使用 `YOUR_GITHUB_USERNAME` 占位符。创建仓库前执行：

```bash
./scripts/configure-repository.sh <GitHub用户名或组织名>
```

然后确认没有遗漏：

```bash
rg 'YOUR_GITHUB_USERNAME' README.md README.zh-CN.md scripts/install-online.sh
```

## 2. 创建本地 Git 仓库

在 `pinyintab` 项目根目录执行：

```bash
git init
git branch -M main
git add .
git commit -m "feat: prepare PinyinTab v0.3.0"
```

提交前应确认 `target/`、`dist/`、`.DS_Store` 和编译产物没有被追踪。

## 3. 在 GitHub 创建空仓库

建议设置：

- Repository name：`pinyintab`
- Description：`Type Pinyin, press Tab, get the real Chinese path.`
- Visibility：Public
- 不勾选自动创建 README、`.gitignore` 或 License，因为本地已经存在
- Topics：`pinyin`、`shell`、`completion`、`bash`、`zsh`、`rust`、`linux`、`macos`

创建后连接远端：

```bash
git remote add origin git@github.com:<owner>/pinyintab.git
git push -u origin main
```

也可以使用 HTTPS remote。第一次推送后检查 Actions 页面，CI 应分别运行 Ubuntu x86_64/Bash 和 macOS arm64/Zsh 测试。

## 4. 版本号规则

项目使用语义化版本：

```text
MAJOR.MINOR.PATCH
  0  .  3  .  0
```

- PATCH：不改变使用方式的 Bug 修复，例如 `0.3.0 → 0.3.1`。
- MINOR：向后兼容的新功能或新平台，例如 `0.3.1 → 0.4.0`。
- MAJOR：1.0 以后出现不兼容配置或协议变化时增加。

0.x 阶段仍应尽量保持兼容，但 Shell 集成结构可能随 MINOR 版本调整。

每次发布必须同步更新：

1. `Cargo.toml` 中的版本。
2. `Cargo.lock`。
3. `CHANGELOG.md`，把 `Unreleased` 内容移动到带日期的版本标题。
4. README 中已经过时的支持范围。

## 5. 创建 Release

先在本地完成：

```bash
cargo test --locked
cargo fmt --all -- --check
cargo clippy --locked --all-targets -- -D warnings
```

提交版本变更并创建带注释标签：

```bash
git add Cargo.toml Cargo.lock CHANGELOG.md README.md README.zh-CN.md
git commit -m "chore: release v0.3.0"
git tag -a v0.3.0 -m "PinyinTab v0.3.0"
git push origin main
git push origin v0.3.0
```

推送 `v*` 标签会触发 `.github/workflows/release.yml`：

```text
v0.3.0 tag
    ├── Ubuntu 22.04 x86_64 build
    │     └── pinyintab-v0.3.0-x86_64-unknown-linux-gnu.tar.gz
    ├── macOS 15 arm64 build
    │     └── pinyintab-v0.3.0-aarch64-apple-darwin.tar.gz
    ├── both SHA-256 files
    └── GitHub Release + automatically generated notes
```

GitHub 页面中看到的版本历史来自 Git tag 和 GitHub Release，不是 README 里的手工列表。`CHANGELOG.md`则提供经过整理的用户可读历史。

## 6. 发布后验证

不要只看工作流变绿。下载两个 Release 包并检查：

```bash
shasum -a 256 -c <archive>.sha256
tar -tzf <archive>
```

分别在真实 Ubuntu x86_64 和 Apple Silicon Mac 上验证：

1. `./install.sh`
2. 新开终端
3. `ptab status`
4. `ptab doctor`
5. `cd` 多级目录补全
6. Python 文件补全
7. 两个同前缀候选继续输入拼音
8. `ptab off` 后恢复原补全
9. `./uninstall.sh`

## 7. Star History 曲线

README 中已经包含 Star History 图片链接。执行仓库所有者配置脚本并公开仓库后，它会根据 GitHub Star 数据自动生成曲线，不需要自己维护 HTML 或数据库。

新仓库没有 Star 时曲线为空是正常现象。不要伪造数据，也不要把 Star 数量当作功能质量证明。

## 8. 演示视频

建议将短演示转换为压缩 GIF 或小体积 MP4：

- 只展示 `ls`、输入拼音、按 Tab、真实中文路径出现、命令成功运行。
- 遮盖用户名、服务器地址、绝对目录和其他隐私信息。
- GIF 可放入 `docs/assets/demo.gif` 并直接嵌入 README。
- 较大的 MP4 建议上传到 GitHub Release 或 Issue/CDN，避免仓库历史永久膨胀。

## 9. GitHub 仓库设置建议

- 开启 Issues 和 Discussions。
- `main` 分支要求 Pull Request、CI 通过后才能合并。
- 开启 Dependabot alerts 和 private vulnerability reporting。
- Release 工作流权限保持最小化：CI 只读，Release 才拥有 `contents: write`。
- 1.0 前保持 Roadmap 和兼容矩阵诚实，不把“预期可用”写成“正式支持”。

## 10. 首发检查清单

- [ ] 仓库所有者占位符已替换。
- [ ] 中英文 README 链接正常。
- [ ] 许可证和作者信息已确认。
- [ ] CI 在两个 Runner 上通过。
- [ ] v0.3.0 标签与 Cargo 版本一致。
- [ ] 两个压缩包和两个校验文件均存在。
- [ ] Ubuntu x86_64 真实安装测试通过。
- [ ] Apple Silicon macOS 真实安装测试通过。
- [ ] 在线安装器能找到最新 Release。
- [ ] 演示视频不存在隐私信息。
- [ ] Star History 链接指向正确仓库。
