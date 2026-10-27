# PinyinTab 系统架构

## 1. 定位

PinyinTab 是 Shell 补全插件，不是输入法、文件系统、解释器包装器或文件重命名工具。它只在用户按下 Tab 时读取本地目录，生成真实路径候选，并交给 Bash/Zsh 写回当前命令行。

```text
用户输入拼音
    ↓
Shell 解析当前命令和光标位置
    ↓
Shell 集成判断参数类型
    ↓
Rust 核心逐层解析路径并匹配拼音
    ↓
Shell 插入真实中文路径
    ↓
用户确认后按 Enter
    ↓
命令或解释器收到普通真实路径
```

这解释了为什么 `python3 ceshi.py<Tab>` 可以工作，而直接按 Enter 会得到“文件不存在”：拼音是补全查询，只有按下 Tab 后才会被真实文件名替换。

## 2. 组件

| 组件 | 文件 | 职责 |
|---|---|---|
| 二进制入口 | `src/main.rs` | 读取进程参数并启动库中的 CLI |
| 命令接口 | `src/cli.rs` | 解析 `ptab` 子命令、过滤模式和退出状态 |
| 参数分类 | `src/context.rs` | 根据 Shell 单词与光标位置区分程序路径、文件参数、表达式和重定向 |
| 拼音映射 | `src/mapper.rs` | 将汉字名称生成全拼和首字母，并处理少量多音词组覆盖 |
| 候选生成 | `src/completion/` | 拆分路径、逐层解析目录、匹配、过滤类型并返回真实候选 |
| 诊断信息 | `src/diagnostics.rs` | 生成版本与平台诊断文本 |
| 帮助参考 | `src/help.rs`、`src/help/` | 统一三种入口的版本化帮助、中文文本与高级接口说明 |
| Bash 集成 | `shell/pinyintab.bash` | 通过 `complete-command` 传递上下文，维护并恢复参数补全和 `complete -I` 首命令补全 |
| Zsh 集成 | `shell/pinyintab.zsh` | 调用 Rust 核心并通过 `compadd` 写入文件与目录候选 |
| 管理入口 | Shell 函数 `ptab` | 提供 `on`、`off`、`status`、`doctor` 和 `version` |
| 自更新 | `src/update.rs`、`scripts/install-online.sh`、`scripts/apply-update.sh` | 定位自身安装前缀，下载校验、暂存替换与失败回滚；不编辑启动配置 |
| 安装与发布 | `install.sh`、`scripts/`、`.github/workflows/` | 用户级安装、卸载、构建归档、CI 与 GitHub Release |

安装器默认只在 Shell 启动文件中加载管理函数，不自动开启补全。`ptab on` 是当前 Shell 的显式状态切换；只有 `--enable-on-startup` 会把自动启用命令写入托管配置块。

管理函数把帮助请求转交给同一二进制参考页。`ptab --help` 为英文，`ptab help zh` 为中文，`ptab help advanced [en|zh]` 显示底层协议。帮助写标准输出并返回 0；用法错误写标准错误并返回 2，不混入候选数据流。帮助请求不触发 `on/off`，有多余操作数的状态命令也会在改变状态前被拒绝。

## 3. 匹配模型

对真实名称 `九九乘法表.py`，核心可以生成：

```text
真实名称：九九乘法表.py
全拼：jiujiuchengfabiao.py
首字母：jjcfb.py
```

候选可由以下输入触发：

- 真实字符前缀：`九九`
- 全拼前缀：`jiujiuchengfa`
- 首字母前缀：`jjcf`
- 中文与拼音混合：`九九cf`
- 带扩展名：`jiujiu.py`

多级路径不是先把整条字符串一次性转换。核心会从左到右解析每一个父目录，得到唯一真实目录后再读取下一层：

```text
ceshimulu/neibuwenjian
    ↓ resolve
测试目录/neibuwenjian
    ↓ resolve
测试目录/内部文件
```

如果父目录拼音同时匹配多个目录，核心不会猜测进入其中一个，以避免补全到错误位置。

### v0.5.0 候选选择策略

`selection.rs` 将语言分组与命令/文件类型过滤解耦。先解析父目录、过滤文件类型和控制字符，再按最后一级名称是否含汉字分组。普通交互请求使用 `auto`：非空查询优先非中文名称，没有时回退中文；空查询保留两组。诊断接口默认 `all`，也可在目录参数前显式传入 `--language`。

在当前分组内，完整真实名称命中立即返回，不再当作前缀扩展。显式 `chinese` 会先排除非中文名称，因此即使真实 `cs1.py` 存在，仍可选择“测试1.py”。数字、扩展名及父目录的歧义规则保持不变。

`shell/keybindings.*` 保存补全前后的命令缓冲区和光标位置。Control+X 后按 c/e 可以在结果未被编辑时恢复原查询并重新请求另一组；否则只查询当前参数。Bash 使用 Readline 原生 complete 动作，Zsh 使用 ZLE completion widget，不自行解析或执行命令。按键绑定在 `ptab off` 时恢复。Tab 不是按键前缀，因此不会引入等候字母的延迟，也不占用裸 Control+C/E。

### v0.6.0 完整名称反向选择

显式请求另一语言组、且当前名称在已解析父目录中真实存在时，核心使用全名等价比较，而不是前缀扩展。中文名的全拼或首字母必须与非中文真实名称完整对应；比较保留数字、扩展名和非汉字部分。例如“测试1.py”对应 `cs1.py` / `ceshi1.py`，不对应 `cs2.py`。普通 Tab 的完整名称优先级不变。显式选择有多个结果时，Shell 只展示候选并保留查询；没有对应项时也不改写。

## 自更新事务

`ptab update` 只接受标准安装布局，源代码构建目录不会被静默替换。Rust 根据正在运行的可执行文件定位 `<prefix>/share/pinyintab/update.sh`，不从 PATH 猜测更新脚本。在线脚本检查稳定版、校验归档 SHA-256、限制归档成员路径并拒绝链接，确认二进制版本后才进入替换。

替换器使用安装前缀内的唯一暂存目录与独占锁，保留未知个人文件，逐项覆盖受管理的集成脚本。二进制通过重命名替换，避免 Linux 上覆盖正在运行的文件。新程序检查失败时尝试恢复旧二进制与集成目录；恢复失败保留备份并报出位置。成功后清理事务备份，下载器退出时清理下载目录。此流程不是跨两个目录的断电原子事务，强制终止和文件系统故障仍可能需要人工恢复。Shell 启动文件不修改，更新后应重新打开终端。

## 4. 命令语义

Shell 集成通过 `complete-command <directory> <zero-based-index> <words...>` 共用上下文分类。独立候选接口保留以下过滤模式：

- `--directories`：用于 `cd`、`rmdir` 等只应接收目录的场景。
- `--files`：供显式只需文件的调用方使用。交互式文件参数采用普通路径模式，保留目录以便继续输入下一层。
- `--java-classes`：用于 `java`，只返回 `.class` 对应的类名并去掉后缀。
- `--executables`：命令位置的路径，只返回至少带一个 Unix 执行位的常规文件，以及导航目录；最终执行权限与格式仍由操作系统检查。

Bash 5 使用 `complete -I` 接入首命令位置，Zsh 使用 `-command-`；Zsh 的 `-redirect-` 单独处理文件重定向。普通不含斜杠的命令名仍使用原生命令补全，不搜索本地中文文件替代 PATH 命令。两类新增钩子均在 `ptab off` 时恢复。

其余命令使用普通路径候选。该模型不是完整的 Shell 语法分析器，复杂命令需要专门规则，详见 `COMPATIBILITY.md`。

## 5. 与解释器的边界

Python、Java、Julia 等解释器不会感知 PinyinTab。以下两条命令对解释器而言完全相同：

```text
用户手动输入：python3 测试.py
PinyinTab 补全：python3 ceshi.py<Tab> → python3 测试.py
```

因此新增语言支持通常不需要修改解释器，只需要判断该命令的当前参数是否应该按照文件、目录或其他专用语义补全。

## 6. 性能

当前实现按一次 Tab 扫描当前目录的一层条目，复杂度近似为 `O(n × m)`：`n` 是这一层目录项数量，`m` 是单个名称长度。它不递归扫描整个项目，也不建立常驻索引，因此普通目录中延迟很小、状态简单。

如果后续为超大目录增加缓存，需要同时解决目录变更失效、内存上限和隐私边界。

## 7. 安全边界

- 补全过程不执行候选文件。
- 路径匹配核心不访问网络；只有显式 `ptab update` 启动的更新辅助脚本访问 Release 服务。
- 候选来自本地目录名称，应继续被视作不可信文本。
- Shell 层必须正确处理空格、Unicode、控制字符、换行和转义字符。
- 安装器只修改当前用户配置，并用固定标记保证可逆。
- 在线安装器下载 Release 后验证 SHA-256，但用户仍应优先检查安装脚本内容。

## 8. 平台结构

首发的两个 Release 使用同一份 Rust 源码：

```text
                         Rust core
                     src/completion/*.rs
                         /      \
                        /        \
 Linux x86_64 + Bash/Zsh          macOS arm64 + Zsh
 x86_64-unknown-linux-gnu         aarch64-apple-darwin
```

Linux Release 在 Ubuntu 22.04、Ubuntu 24.04 与 CentOS Stream 9 上执行同一归档的安装和补全测试，运行时基线为 glibc 2.34。平台差异主要存在于 Shell 补全 API、安装配置文件和二进制目标格式，不在拼音匹配算法本身。
