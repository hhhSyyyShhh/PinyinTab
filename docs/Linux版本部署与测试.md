# PinyinTab v0.3.0 Linux 版本部署与测试

## 1. 版本能力

Linux v0.3.0 使用 Rust 核心和 Bash 可编程补全，不再使用 FUSE，因此不需要 `/dev/fuse`，也不需要进入虚拟挂载目录。

已包含：

- 中文全拼和首字母补全。
- 当前真实目录直接补全。
- 多级纯拼音路径。
- 中文与拼音混合路径。
- `cd` 只返回目录。
- `cat`、`python3`、`julia` 等只返回文件。
- `cp`、`mv`、`rm` 等支持文件和目录。
- 目录末尾按 `Tab` 列出下一层。
- `jiujiu.py` 匹配 `九九乘法表.py`。
- `cfkjb.py` 匹配 `乘法口诀表.py`。
- `python3.10` 至 `python3.14`。
- `java cfkjb<Tab>` 补成不含 `.class` 的 `java 乘法口诀表`。
- 多个候选先补出共同中文前缀后，可以继续输入拼音再次缩小范围。
- 混合输入仍有多个候选时保留原输入，并展示真实候选列表。
- 开启和关闭时保存、恢复原 Bash 补全定义。

## 2. Ubuntu 准备环境

如果使用 GitHub Release 中的预编译包，不需要安装 Rust、Cargo、FUSE 或编译工具，只需要系统自带的 Bash、`tar` 和基础命令。

下面的 Rust 环境只供从源码开发和测试使用。

如果 Rust 已经安装，只需要刷新当前 Shell：

```bash
source "$HOME/.cargo/env"
cargo --version
```

如果系统缺少基础编译工具：

```bash
sudo apt update
sudo apt install -y build-essential pkg-config curl
```

当前版本不需要安装 `fuse3` 或 `libfuse3-dev`。

## 3. 解压

假设安装包上传到了 `~/linux_demo`：

```bash
cd ~/linux_demo
tar -xzf pinyintab-v0.3.0-x86_64-unknown-linux-gnu.tar.gz
cd pinyintab-v0.3.0-x86_64-unknown-linux-gnu
```

如果当前终端加载了旧版，先执行：

```bash
ptab off
```

旧终端找不到 `ptab` 时可以忽略这一步。

## 4. 从源码一键测试（Release 用户可以跳过）

```bash
./scripts/test-linux.sh
```

脚本会执行：

1. Rust 单元测试。
2. Release 编译。
3. Bash 补全兼容性测试。
4. 系统与 Bash 版本检查。

最后应该出现：

```text
PASS: PinyinTab Linux v0.3.0 test suite
```

## 5. 安装和启动

```bash
./install.sh
source ~/.bashrc
```

安装位置：

```text
~/.local/bin/ptab
~/.local/share/pinyintab/pinyintab.bash
```

不需要 root 权限。

## 6. 手工测试

```bash
cd demo-source
```

以下示例中的 `<Tab>` 表示按键盘上的 Tab 键，不是输入这五个字符。

### Python

```bash
python3 cfkjb.py<Tab>
# python3 乘法口诀表.py
```

或者：

```bash
python3 jiujiu.py<Tab>
# python3 九九乘法表.py
```

### Julia

```bash
julia cfkjb.jl<Tab>
# julia 乘法口诀表.jl
```

### Java

```bash
javac -encoding UTF-8 cfkjb.java<Tab>
# javac -encoding UTF-8 乘法口诀表.java

java cfkjb<Tab>
# java 乘法口诀表
```

`java` 后面不能带 `.class`。

### 多级目录

```bash
python3 ceshimulu/neibujiao<Tab>
# python3 测试目录/内部脚本.py

cat ceshimulu/neibuwenjianjia/<Tab>
# cat 测试目录/内部文件夹/深层说明.txt
```

### 文件和目录过滤

```bash
cat ceshimulu<Tab>
```

如果匹配到的只有 `测试目录/`，`cat` 不会把它补出来。

```bash
cd ceshimulu<Tab>
# cd 测试目录/
```

## 7. 关闭

```bash
ptab off
```

Linux v0.3.0 不使用 FUSE，所以不需要 `fusermount3 -u`。

## 8. 设置自动启动

普通安装器会自动把下面两行加入 `~/.bashrc`，不需要重复添加。如果安装时使用了 `--no-modify-shell`，才需要手动配置：

```bash
source "$HOME/.local/share/pinyintab/pinyintab.bash"
ptab on
```

重新打开 SSH，或者运行：

```bash
source ~/.bashrc
```

## 9. 故障排查

### `cargo: command not found`

```bash
source "$HOME/.cargo/env"
```

### 拼音按回车后提示文件不存在

必须先按 `Tab`，确认命令行已经变成真实中文名称，再按 Enter。

### 仍然加载旧版行为

```bash
ptab off
source "$HOME/.local/share/pinyintab/pinyintab.bash"
ptab on
```

如果刚刚重新编译过，应再次执行 `./scripts/install-from-source.sh`，否则 `~/.local/bin/ptab` 仍可能是旧二进制。

### Java 报找不到主类

错误：

```bash
java 乘法口诀表.class
```

正确：

```bash
java 乘法口诀表
```

### 查看插件核心是否可用

```bash
ptab doctor
ptab alias 测试.py
ptab complete "$PWD" ceshi.py --files
```
