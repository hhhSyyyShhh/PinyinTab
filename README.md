# PinFS v0.2.2

PinyinTab 更名前的 Shell 路径补全原型。本快照于 2026-10-27 从本地存档补录，保留原程序名和 `Cargo.toml` 中的版本号；这不是当年的在线发布记录。

推荐安装 [PinyinTab 当前版本](https://github.com/hhhSyyyShhh/PinyinTab#安装)。此处仅用于追溯，不提供预编译程序，也不接收功能更新。

## 内容与来源

- 来源存档：`pinfs-demo-2.2`。
- 保留 Rust 源码、Cargo 配置、Shell 脚本和源码示例；未包含生成文件、编译程序及研发笔记。
- 原始文件哈希见 `SOURCE_MANIFEST.sha256`。本说明、清单和 MIT 许可证为补录时添加。
- 所选原始源码文件清单 SHA-256：`a0fd1769fa200259b4df1c93123074811218b62b7323fee5c09a715615a201a9`。

## 核对范围

本次本地 macOS 上的 `cargo test --offline --locked --all-targets` 与脚本语法检查：通过。没有以当前 CI 重验旧版全部 Shell 交互或 Linux 发行版兼容性。

## 构建

```bash
cargo test --locked
cargo build --release --locked
```

历史安装脚本仍使用 `pinfs` 名称。新安装和升级请使用当前 PinyinTab 发布包。
