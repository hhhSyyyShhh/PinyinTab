#!/usr/bin/env python3
"""Verify shared binary/Bash/Zsh help without modifying the user's shell files."""
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    project = Path(__file__).resolve().parent.parent
    binary = Path(os.environ.get("PINYINTAB_BINARY", project / "target/release/ptab")).resolve()
    shell = shutil.which(sys.argv[1] if len(sys.argv) > 1 else "bash")
    if not shell:
        raise SystemExit("requested shell is unavailable")
    is_zsh = shell.endswith("zsh")
    suffix = "zsh" if is_zsh else "bash"
    shell_args = [shell, "-f", "-c"] if is_zsh else [shell, "--noprofile", "--norc", "-c"]
    integration = project / "shell" / f"pinyintab.{suffix}"
    env = dict(os.environ, PINYINTAB_BINARY=str(binary))
    setup = "source " + shlex.quote(str(integration)) + "; "
    checks = 0

    def invoke(args, prefix=""):
        return subprocess.run(shell_args + [setup + prefix + "ptab " + shlex.join(args)],
                              env=env, capture_output=True, text=True)

    for args in [[], ["--help"], ["-h"], ["help"], ["help", "en"],
                 ["help", "zh"], ["--help", "zh"], ["help", "advanced"],
                 ["help", "advanced", "zh"], ["version"], ["--version"], ["-V"]]:
        actual = invoke(args)
        expected = subprocess.run([str(binary)] + args, capture_output=True, text=True)
        assert actual.returncode == expected.returncode == 0, (args, actual.stderr)
        assert actual.stdout == expected.stdout, args
        assert not actual.stderr and not expected.stderr, args
        checks += 1

    for args in [["help", "fr"], ["help", "zh", "extra"], ["not-a-command"],
                 ["on", "extra"], ["off", "extra"], ["status", "extra"],
                 ["doctor", "extra"], ["version", "extra"]]:
        result = invoke(args)
        assert result.returncode == 2 and not result.stdout and result.stderr, args
        checks += 1

    # A shared binary call must not insert help into the candidate stream.
    result = invoke(["complete-command", str(project), "1", "cat", "Cargo.to"])
    assert result.returncode == 0 and result.stdout == "Cargo.toml\n" and not result.stderr
    checks += 1

    with tempfile.TemporaryDirectory(prefix="pinyintab-help-test-") as directory:
        cache = shlex.quote(str(Path(directory) / ".zcompdump"))
        init = f"autoload -Uz compinit; compinit -d {cache}; " if is_zsh else ""
        for active in [False, True]:
            prefix = init + ("ptab on >/dev/null; " if active else "")
            for request in ["ptab --help", "ptab help zh", "ptab help advanced", "ptab on extra"]:
                # All state is confined to this child shell; cache goes to our fixture.
                code = (setup + prefix + 'before="$(ptab status)"; '
                        + request + ' >/dev/null 2>/dev/null; '
                        + 'after="$(ptab status)"; [[ "$before" == "$after" ]]')
                result = subprocess.run(shell_args + [code], env=env, capture_output=True, text=True)
                assert result.returncode == 0, (active, request, result.stderr)
                checks += 1

    print(f"PASS: {suffix}: {checks} help checks (text, streams, status, protocol, state)")


if __name__ == "__main__":
    main()
