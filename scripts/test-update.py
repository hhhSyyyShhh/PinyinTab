#!/usr/bin/env python3
"""Offline update tests: fake transport, real archives, real install transaction.

All writes, including the mock installation and HOME, live in one temporary
directory. No GitHub credentials, current shell or real installation are used.
"""
import hashlib
import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path


PROJECT = Path(__file__).resolve().parent.parent
CHECKS = 0


def fixture(root, *, tag="v0.6.0", bad_hash=False, fail_download=False,
            bad_doctor=False, missing=False, unsafe=False, link=False):
    prefix = root / "prefix"
    share = prefix / "share/pinyintab"
    share.mkdir(parents=True)
    (prefix / "bin").mkdir()
    old_binary = prefix / "bin/ptab"
    old_binary.write_text("#!/bin/sh\necho 'PinyinTab 0.5.1'\n")
    old_binary.chmod(0o755)
    (share / "pinyintab.bash").write_text("old integration\n")
    (share / "personal.toml").write_text("keep = true\n")
    (root / "home").mkdir()
    (root / "home/.zshrc").write_text("# unchanged startup\n")
    target = "aarch64-apple-darwin" if os.uname().sysname == "Darwin" else "x86_64-unknown-linux-gnu"
    name = f"pinyintab-{tag}-{target}"
    package = root / name
    (package / "bin").mkdir(parents=True)
    (package / "shell").mkdir()
    binary = package / "bin/ptab"
    binary.write_text("#!/bin/sh\n" + ("[ \"$1\" != doctor ] || exit 1\n" if bad_doctor else "")
                      + f"echo 'PinyinTab {tag[1:]}'\n")
    binary.chmod(0o755)
    for source in ["pinyintab.bash", "pinyintab.zsh", "keybindings.bash", "keybindings.zsh"]:
        shutil.copy2(PROJECT / "shell" / source, package / "shell" / source)
    shutil.copy2(PROJECT / "scripts/install-online.sh", package / "update.sh")
    shutil.copy2(PROJECT / "scripts/apply-update.sh", package / "apply-update.sh")
    shutil.copy2(PROJECT / "uninstall.sh", package / "uninstall.sh")
    if missing:
        (package / "shell/keybindings.zsh").unlink()
    archive = root / f"{name}.tar.gz"
    with tarfile.open(archive, "w:gz") as output:
        output.add(package, arcname=name)
        if unsafe:
            item = tarfile.TarInfo(f"{name}/../../escape")
            item.size = 4
            output.addfile(item, io.BytesIO(b"bad!"))
        if link:
            item = tarfile.TarInfo(f"{name}/symlink")
            item.type = tarfile.SYMTYPE
            item.linkname = "/tmp"
            output.addfile(item)
    digest = "0" * 64 if bad_hash else hashlib.sha256(archive.read_bytes()).hexdigest()
    (root / f"{name}.tar.gz.sha256").write_text(f"{digest}  {name}.tar.gz\n")
    (root / "metadata").write_text(json.dumps({"tag_name": tag}))
    tools = root / "tools"
    tools.mkdir()
    mock = tools / "curl"
    mock.write_text('''#!/usr/bin/env python3
import os, pathlib, shutil, sys
root = pathlib.Path(os.environ["UPDATE_FIXTURE"])
args = sys.argv[1:]
url = next((word for word in args if word.startswith("https://")), "")
with (root / "requests").open("a") as stream:
    stream.write(url + "\\n")
if os.environ.get("FAIL_DOWNLOAD") == "1":
    sys.exit(28)
if url.endswith("/releases/latest"):
    print((root / "metadata").read_text())
else:
    shutil.copyfile(root / url.rsplit("/", 1)[-1], args[args.index("-o") + 1])
''')
    mock.chmod(0o755)
    scratch = root / "scratch"
    scratch.mkdir()
    env = dict(os.environ, HOME=str(root / "home"), TMPDIR=str(scratch),
               PINYINTAB_INSTALL_ROOT=str(prefix), UPDATE_FIXTURE=str(root),
               PATH=str(tools) + os.pathsep + os.environ["PATH"],
               FAIL_DOWNLOAD="1" if fail_download else "0")
    env.pop("PINYINTAB_REPOSITORY", None)
    return prefix, env, scratch


def run_case(label, *, current="0.5.1", success=True, changed=True, locked=False, **options):
    global CHECKS
    with tempfile.TemporaryDirectory(prefix="pinyintab-update-test-") as directory:
        root = Path(directory)
        prefix, env, scratch = fixture(root, **options)
        if locked:
            (prefix / ".pinyintab-update-lock").mkdir()
        result = subprocess.run(["bash", str(PROJECT / "scripts/install-online.sh"), "--update", current],
                                env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == success, (label, result.stdout, result.stderr)
        expected = options.get("tag", "v0.6.0")[1:] if changed and success else "0.5.1"
        actual = subprocess.check_output([str(prefix / "bin/ptab"), "version"], text=True)
        assert actual.strip() == f"PinyinTab {expected}", (label, actual)
        assert (prefix / "share/pinyintab/personal.toml").read_text() == "keep = true\n", label
        assert (root / "home/.zshrc").read_text() == "# unchanged startup\n", label
        assert not list(scratch.iterdir()), (label, "download staging was not cleaned")
        assert not list(prefix.glob(".pinyintab-update.*")), (label, "transaction staging remains")
        if not locked:
            assert not (prefix / ".pinyintab-update-lock").exists(), label
        if changed and success:
            assert (prefix / "share/pinyintab/update.sh").is_file(), label
            assert (prefix / "share/pinyintab/pinyintab.bash").read_bytes() == (PROJECT / "shell/pinyintab.bash").read_bytes()
        else:
            assert (prefix / "share/pinyintab/pinyintab.bash").read_text() == "old integration\n", label
        assert not (root / "escape").exists(), label
        if not changed and success:
            assert len((root / "requests").read_text().splitlines()) == 1, label
        CHECKS += 1


def main():
    global CHECKS
    run_case("verified update")
    run_case("same version", current="0.6.0", changed=False)
    run_case("no downgrade", current="0.7.0", changed=False)
    run_case("numeric ordering", current="0.9.0", tag="v0.10.0")
    run_case("network failure", fail_download=True, success=False)
    run_case("bad checksum", bad_hash=True, success=False)
    run_case("startup check rollback", bad_doctor=True, success=False)
    run_case("missing helper", missing=True, success=False)
    run_case("traversal rejected", unsafe=True, success=False)
    run_case("links rejected", link=True, success=False)
    run_case("unsupported release tag", tag="v0.6.0-rc1", success=False)
    run_case("concurrent update", locked=True, success=False)
    # Exercise the real Rust dispatcher and both loaded shell wrappers. The
    # current executable locates its own prefix, not a caller-supplied one.
    for entry in ["binary", "bash", "zsh"]:
        if entry != "binary" and not shutil.which(entry):
            continue
        with tempfile.TemporaryDirectory(prefix="pinyintab-update-dispatch-") as directory:
            root = Path(directory)
            prefix, env, scratch = fixture(root, tag="v99.0.0")
            binary = prefix / "bin/ptab"
            shutil.copy2(PROJECT / "target/release/ptab", binary)
            shutil.copy2(PROJECT / "scripts/install-online.sh", prefix / "share/pinyintab/update.sh")
            env["PINYINTAB_BINARY"] = str(binary)
            env["PINYINTAB_INSTALL_ROOT"] = "/pinyintab-wrong-prefix-must-not-be-used"
            command = [str(binary), "update"]
            if entry != "binary":
                integration = PROJECT / f"shell/pinyintab.{entry}"
                command = [entry, "-c", 'source "$1"; ptab update', "test", str(integration)]
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            assert result.returncode == 0, (entry, result.stdout, result.stderr)
            assert subprocess.check_output([str(binary), "version"], text=True).strip() == "PinyinTab 99.0.0"
            assert not list(scratch.iterdir()), entry
            CHECKS += 1
    print(f"PASS: {CHECKS} offline update checks (download, SHA-256, rollback, cleanup, configuration)")


if __name__ == "__main__":
    main()
