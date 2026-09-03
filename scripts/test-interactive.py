#!/usr/bin/env python3
"""Real Tab-key regression tests. Only commands in disposable fixtures execute.

No third-party Python modules are required. A probe key reports Readline/ZLE's
actual edited buffer, so these tests exercise dispatch, quoting and insertion.
"""
import os
import pty
import select
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


class Terminal:
    def __init__(self, shell, root, integration, binary):
        self.master, slave = pty.openpty()
        env = dict(os.environ, HOME=str(root), ZDOTDIR=str(root), TERM="xterm",
                   PINYINTAB_BINARY=str(binary), LC_ALL="en_US.UTF-8")
        args = [shell, "-f", "-i"] if shell.endswith("zsh") else [shell, "--noprofile", "--norc", "-i"]
        self.process = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave,
                                        cwd=root, env=env, start_new_session=True)
        os.close(slave)
        self.pending = b""
        if shell.endswith("zsh"):
            setup = "PROMPT='ptab> '; RPROMPT=''; _probe() { print -r -- __BUFFER_BEGIN__; print -r -- \"$BUFFER\"; print -r -- __BUFFER_END__; BUFFER=''; zle redisplay; }; zle -N _probe; bindkey '^X^G' _probe; "
        else:
            setup = "PS1='ptab> '; _probe() { printf '\\n__BUFFER_BEGIN__\\n%s\\n__BUFFER_END__\\n' \"$READLINE_LINE\"; READLINE_LINE=''; READLINE_POINT=0; }; bind -x '\"\\C-x\\C-g\":_probe'; "
        self.send(setup + "source " + shlex.quote(str(integration)) + "; ptab on; printf '\\n__READY_%s__\\n' OK\n")
        self.until(b"__READY_OK__")

    def send(self, value):
        os.write(self.master, value.encode())

    def until(self, marker, timeout=15):
        deadline = time.monotonic() + timeout
        while marker not in self.pending:
            if time.monotonic() > deadline:
                raise AssertionError(f"terminal timeout for {marker!r}: {self.pending[-3000:]!r}")
            if select.select([self.master], [], [], 0.1)[0]:
                self.pending += os.read(self.master, 65536)
        found, self.pending = self.pending.split(marker, 1)
        return found

    def probe(self, typed):
        self.send(typed + "\t\x18\x07")
        self.until(b"__BUFFER_BEGIN__\r\n")
        return self.until(b"\r\n__BUFFER_END__").decode().strip()

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        os.close(self.master)


def main():
    project = Path(__file__).resolve().parent.parent
    binary = Path(os.environ.get("PINYINTAB_BINARY", project / "target/release/ptab")).resolve()
    shell = shutil.which(sys.argv[1] if len(sys.argv) > 1 else "zsh")
    if not shell:
        raise SystemExit("requested shell is unavailable")
    if not shell.endswith("zsh"):
        supported = subprocess.run([shell, "-c", "complete -p -I"], capture_output=True)
        if b"invalid option" in supported.stderr:
            print("SKIP: command-position Tab requires Bash 5+ (macOS ships Bash 3.2); test Zsh here")
            return
    with tempfile.TemporaryDirectory(prefix="pinyintab-interactive-") as name:
        root = Path(name)
        program = root / "运行程序"
        program.write_text("#!/bin/sh\nprintf 'PTAB_EXEC_OK\\n'\n")
        program.chmod(0o755)
        (root / "运行说明.txt").write_text("not executable")
        (root / "测试目录").mkdir()
        (root / "测试目录" / "内部程序").write_bytes(program.read_bytes())
        (root / "测试目录" / "内部程序").chmod(0o755)
        (root / "说明.txt").write_text("hello\n")
        (root / "项目 说明.txt").write_text("hello\n")
        (root / "test").mkdir()
        (root / "图片").mkdir()
        suffix = "zsh" if shell.endswith("zsh") else "bash"
        terminal = Terminal(shell, root, project / "shell" / f"pinyintab.{suffix}", binary)
        cases = [
            ("./yunxing", "./运行程序"),
            (f"../{root.name}/yunxing", f"../{root.name}/运行程序"),
            (f"{root}/yunxing", f"{root}/运行程序"),
            ("./ceshimulu/neibu", "./测试目录/内部程序"),
            ("true && ./yunxing", "true && ./运行程序"),
            ("printf ok | ./yunxing", "printf ok | ./运行程序"),
            ("sudo -u root ./yunxing", "sudo -u root ./运行程序"),
            ("cat ceshimulu", "cat 测试目录/"),
            ("cat < shuoming", "cat < 说明.txt"),
            ("cat << shuoming", "cat << shuoming"),
            ("cat >& shuoming", "cat >& shuoming"),
            ("printf ok > shuoming", "printf ok > 说明.txt"),
            ("grep hello shuoming", "grep hello 说明.txt"),
            ("grep -n hello shuoming", "grep -n hello 说明.txt"),
            ("grep shuoming", "grep shuoming"),
            ("sed shuoming", "sed shuoming"),
            ("awk shuoming", "awk shuoming"),
            ("find . -name shuoming", "find . -name shuoming"),
            ("chmod +x shuoming", "chmod +x 说明.txt"),
            ("head -n shuoming", "head -n shuoming"),
            ("python3 -m shuoming", "python3 -m shuoming"),
            ("cd t", "cd t"),
            ("cd tu", "cd 图片/"),
        ]
        cases += [(f"{cmd} shuoming", f"{cmd} 说明.txt") for cmd in
                  ["ls", "stat", "file", "wc", "sort", "uniq", "diff", "du", "cp", "mv", "rm", "ln", "readlink", "realpath", "tee"]]
        try:
            for typed, expected in cases:
                actual = terminal.probe(typed)
                assert actual == expected, f"{suffix}: {typed!r}: expected {expected!r}, got {actual!r}"
            spaced = terminal.probe("cat xiangmu")
            assert shlex.split(spaced) == ["cat", "项目 说明.txt"], repr(spaced)
            terminal.send("./yunxing\t\n")
            terminal.until(b"PTAB_EXEC_OK\r\n")
            terminal.send("ptab off\n")
            terminal.until(b"PinyinTab completion: OFF")
            assert terminal.probe("./yunxing") == "./yunxing", "off did not restore command completion"
            print(f"PASS: {suffix}: {len(cases) + 3} real-terminal checks (Tab buffers, quoting, execution, off)")
        finally:
            terminal.close()


if __name__ == "__main__":
    main()
