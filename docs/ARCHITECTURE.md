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
| 拼音映射库 | `src/lib.rs` | 将汉字名称生成全拼和首字母，并处理少量多音词组覆盖 |
| 候选生成程序 | `src/main.rs` | 拆分路径、逐层解析目录、过滤文件类型、排序并输出候选 |
| Bash 集成 | `shell/pinyintab.bash` | 读取光标处单词，调用 `ptab complete`，维护并恢复 Bash 补全定义 |
| Zsh 集成 | `shell/pinyintab.zsh` | 调用 Rust 核心并通过 `compadd` 写入文件与目录候选 |
| 管理入口 | Shell 函数 `ptab` | 提供 `on`、`off`、`status`、`doctor` 和 `version` |
| 安装与发布 | `install.sh`、`scripts/`、`.github/workflows/` | 用户级安装、卸载、构建归档、CI 与 GitHub Release |

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

## 4. 命令语义

Shell 集成提供三种候选过滤：

- `--directories`：用于 `cd`、`rmdir` 等只应接收目录的场景。
- `--files`：用于 Python、Julia、`cat` 等文件参数。
- `--java-classes`：用于 `java`，只返回 `.class` 对应的类名并去掉后缀。

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

未来若为超大目录增加缓存，需要同时解决目录变更失效、内存上限和隐私边界，不能只追求基准测试速度。

## 7. 安全边界

- 补全过程不执行候选文件。
- Rust 核心不访问网络。
- 候选来自本地目录名称，应继续被视作不可信文本。
- Shell 层必须正确处理空格、Unicode、控制字符、换行和转义字符。
- 安装器只修改当前用户配置，并用固定标记保证可逆。
- 在线安装器下载 Release 后验证 SHA-256，但用户仍应优先检查安装脚本内容。

## 8. 平台结构

首发的两个 Release 使用同一份 Rust 源码：

```text
                         Rust core
                         src/*.rs
                         /      \
                        /        \
       Linux x86_64 + Bash        macOS arm64 + Zsh
 x86_64-unknown-linux-gnu         aarch64-apple-darwin
```

平台差异主要存在于 Shell 补全 API、安装配置文件和二进制目标格式，不在拼音匹配算法本身。
