# PinyinTab 兼容边界

## 正式支持的平台

| 系统 | CPU | 默认 Shell | 测试方式 |
|---|---|---|---|
| Ubuntu 22.04、24.04 | x86_64 / AMD64 | Bash | GitHub Actions Runner/容器 + Release 安装测试 |
| CentOS Stream 9 | x86_64 / AMD64 | Bash | 官方容器 + Release 安装测试 |
| macOS 14 及更新版本 | Apple Silicon arm64 | Zsh | GitHub Actions M 系列 Runner + Zsh 回归脚本 |

Linux Release 使用 `x86_64-unknown-linux-gnu`，要求 glibc 2.34 或更新版本。它通常也能运行在满足版本要求的 Debian、Fedora、RHEL、Rocky Linux、AlmaLinux 等 x86_64 发行版上，但未经 CI 验证的平台只标记为“预期可用”。Alpine 默认使用 musl；旧发行版可能缺少所需 glibc；ARM 服务器无法运行 x86_64 二进制。

CentOS Linux 7/8 与 CentOS Stream 8 已停止维护，并且不满足当前 Release 的运行时基线，因此不属于支持平台。“支持 CentOS”在本项目中明确指 CentOS Stream 9 x86_64，而不是所有历史 CentOS 版本。

## 安装后的启用策略

普通安装会在 Shell 配置中加载 PinyinTab 集成，使 `ptab` 命令可用，但不会自动执行 `ptab on`。用户可以在需要拼音补全的当前 Shell 中手动启用：

```bash
ptab on
```

希望每次打开新终端都启用的用户，需要在安装时明确传入：

```bash
bash install-online.sh --enable-on-startup
```

重新安装会更新 PinyinTab 固定标记之间的托管配置，并保留标记外的用户配置和首次安装备份。

## 已覆盖行为

- 中文、ASCII 和中英混合名称。
- 全拼与拼音首字母。
- 文件扩展名。
- 名称中的空格。
- 多级真实中文路径和多级纯拼音输入。
- 输入空前缀后列出非隐藏项目。
- 多候选公共前缀后继续输入拼音缩小范围。
- `cd` 等目录限定命令。
- Python、Julia、Ruby、Perl、Node、编译器等文件型参数。
- Java 源文件与 `.class` 类名的不同语义。
- Bash 管道后的当前命令识别。
- `ptab off` 恢复启用前的补全定义。
- 新终端默认保持补全关闭，除非安装时明确选择自动启用。

## 不是“所有命令都无条件支持”

### v0.4.1 命令上下文回归范围

| 上下文 | 示例 | 处理方式 |
|---|---|---|
| 直接执行路径 | `./yunxing<Tab>`、`../yunxing<Tab>`、`/tmp/yunxing<Tab>` | 可执行文件和导航目录，保留路径前缀 |
| 命令链 | `true && ./yunxing<Tab>`、`printf ok \| ./yunxing<Tab>` | 在新命令位置使用可执行过滤 |
| 常见包装器 | `sudo -u root ./yunxing<Tab>`、`env LANG=C ./yunxing<Tab>` | 识别已知包装器参数后判断实际命令 |
| 本地路径 | `ls/stat/file/wc/sort/uniq/diff/du/cp/mv/rm/ln/readlink/realpath/tee` 的路径参数 | 文件与导航目录 |
| 模式参数 | `grep 模式 文件`、`sed 表达式 文件`、`awk 程序 文件` | 模式不转换，文件可补全；常见 `-e/-f` 另行区分 |
| 权限与查找 | `chmod +x 文件`、`chown root 文件`、`find 目录` | 权限/用户不转成文件；find 谓词区域不自动转换 |
| 数值与分隔符 | `head -n 10`、`cut -d ,`、`sort -k 1`、`tr 集合1 集合2` | 已知非路径位置不生成拼音候选 |
| 文件重定向 | `cat < 文件`、`printf ok > 文件` | 补全已存在路径，不凭空创建中文文件 |
| 解释器 | `python3 文件` 与 `python3 -m 模块` | 文件可以补全，模块名和内联代码不转换 |

`./` 是相对路径前缀，不是单独的命令。仍需按 Tab；拼音直接回车不会自动改写。执行位检查跟随符号链接，但不保证目标格式、ACL、挂载选项或解释器可执行。

首命令补全在 Linux Bash 5.x 和 macOS Zsh 上验证；macOS 自带 Bash 3.2 缺少 `complete -I`，只保留已有参数补全能力。

扩展工具可在加载集成脚本之前设置 Shell 数组：

```bash
PINYINTAB_EXTRA_COMMANDS=(my-local-tool another-tool)
source "$HOME/.local/share/pinyintab/pinyintab.bash" # Zsh 使用 .zsh
ptab on
```

这只为普通本地路径参数显式注册补全，不理解工具的子命令或专用语言。复杂工具应增加 `src/context.rs` 适配和回归测试；启用期间会接管所列命令，关闭时恢复，不宣称与所有第三方补全器完全叠加。

Tab 补全由 Shell、命令自己的补全器以及 PinyinTab 共同决定。下列情况需要单独设计，不能用一个通用文件扫描规则保证正确：

| 场景 | 原因 |
|---|---|
| `scp host:path`、`rsync host:path` | 冒号后的路径可能位于远程机器 |
| URL、Git remote、对象存储地址 | 看似路径但不是本地文件系统路径 |
| here-document 和多行 Shell 语法 | 当前单词不等同于普通路径参数 |
| `--option=value` | 路径可能嵌在程序自定义选项语法里 |
| 已有复杂第三方补全插件 | 两个补全器需要组合，而不是简单覆盖 |
| SSH 远程命令 | 本地 PinyinTab 看不到远端目录 |
| 文件名含换行或控制字符 | Shell 显示和候选传输需要额外编码规则 |
| Java 包名和模块路径 | `java` 参数不一定是当前目录下的单一类名 |

## 命令链和管道

Bash 集成会在 `|`、`||`、`&&` 和 `;` 后重新确定当前命令，因此普通命令链可以工作。但引号、子 Shell、命令替换、函数包装和程序专用 DSL 可能需要更完整的 Shell 语法状态。

## 与原生补全器共存

启用时，PinyinTab 保存常用命令和默认补全器的先前定义；关闭时恢复它们。仍有两类风险：

1. PinyinTab 启用后，另一个插件再次修改相同命令的补全器。
2. 第三方框架动态生成补全定义，无法仅靠保存一条定义完全还原其内部状态。

测试新 Shell 框架时应至少验证：启用前补全、启用后的拼音补全、关闭后的原补全、重复开关和新终端自动加载。

`ptab doctor` 在 Linux 上会同时报告发行版名称与 glibc 版本，提交兼容性问题时应附上完整输出。

## 文件系统与编码

PinyinTab 按操作系统返回的真实 Unicode 名称工作，不负责 Unicode 正规化转换。macOS 与 Linux 对组合字符的存储可能不同。无法转换为 UTF-8 的 Unix 文件名当前会被跳过。

符号链接会按目录读取结果参与候选；权限不足、目录在扫描期间被删除等错误不会被伪造成有效候选。含控制字符（包括换行）的名称会被跳过，防止行分隔协议把一个文件名拆成多个候选。

## 新平台进入正式支持的条件

一个新平台必须同时具备：

- 可重复的 CI Runner；
- 对应架构的 Release 二进制；
- Shell 集成测试；
- 安装与卸载验证；
- 归档校验和；
- README 兼容矩阵更新；
- 至少一台真实设备的手动冒烟测试。
