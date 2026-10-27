use std::process::Command;

fn run(args: &[&str]) -> std::process::Output {
    Command::new(env!("CARGO_BIN_EXE_ptab"))
        .args(args)
        .output()
        .unwrap()
}

#[test]
fn command_protocol_rejects_bad_indices_and_non_path_contexts() {
    for args in [
        vec!["complete-command"],
        vec!["complete-command", ".", "bad"],
    ] {
        assert_eq!(run(&args).status.code(), Some(2));
    }
    for args in [
        vec!["complete-command", ".", "99", "cat", "ce"],
        vec!["complete-command", ".", "1", "grep", "ce"],
        vec!["complete-command", ".", "0", "cat"],
    ] {
        let result = run(&args);
        assert!(result.status.success());
        assert!(result.stdout.is_empty());
    }
}

#[test]
fn command_protocol_returns_paths_and_reports_missing_directories() {
    let result = run(&[
        "complete-command",
        env!("CARGO_MANIFEST_DIR"),
        "1",
        "cat",
        "Cargo.to",
    ]);
    assert!(result.status.success());
    assert_eq!(String::from_utf8(result.stdout).unwrap(), "Cargo.toml\n");
    let result = run(&[
        "complete-command",
        "/pinyintab-test-nonexistent-directory",
        "1",
        "cat",
        "ce",
    ]);
    assert!(!result.status.success());
    assert!(!result.stderr.is_empty());
}

#[test]
fn language_selection_keeps_protocol_data_and_command_context_separate() {
    let directory = format!("{}/demo-source", env!("CARGO_MANIFEST_DIR"));
    for command in ["complete", "complete-command"] {
        for (language, expected) in [
            ("chinese", "测试.py\n"),
            ("auto", "测试.py\n"),
            ("english", ""),
        ] {
            let mut args = vec![command, "--language", language, &directory];
            if command == "complete-command" {
                args.extend(["1", "vim"]);
            }
            args.push("ceshi.py");
            let result = run(&args);
            assert!(result.status.success(), "{args:?}");
            assert!(result.stderr.is_empty());
            assert_eq!(String::from_utf8(result.stdout).unwrap(), expected);
        }
        for args in [
            vec![command, "--language"],
            vec![command, "--language", "invalid"],
            vec![command, "--language", "auto"],
        ] {
            let result = run(&args);
            assert_eq!(result.status.code(), Some(2), "{args:?}");
            assert!(result.stdout.is_empty());
            assert!(!result.stderr.is_empty());
        }
    }
    let result = run(&[
        "complete-command",
        "--language",
        "chinese",
        &directory,
        "1",
        "grep",
        "ceshi",
    ]);
    assert!(result.status.success());
    assert!(
        result.stdout.is_empty(),
        "language selection must not turn a grep pattern into a path"
    );
}

#[test]
fn help_aliases_use_stdout_and_succeed() {
    let expected = run(&["--help"]).stdout;
    for args in [
        vec![],
        vec!["help"],
        vec!["-h"],
        vec!["--help"],
        vec!["help", "en"],
    ] {
        let result = run(&args);
        assert!(result.status.success(), "{args:?}");
        assert!(result.stderr.is_empty(), "{args:?}");
        assert_eq!(result.stdout, expected);
    }
    let text = String::from_utf8(expected).unwrap();
    for section in [
        "Usage:",
        "Shell commands",
        "Commands:",
        "Options:",
        "Examples:",
        "Notes:",
    ] {
        assert!(text.contains(section), "{section}");
    }
    assert!(text.contains(env!("CARGO_PKG_VERSION")));
    assert!(text.contains("not uninstall"));
    assert!(!text.contains("complete-command <"));
}

#[test]
fn chinese_and_advanced_help_are_available() {
    let general = run(&["help", "zh"]);
    assert!(general.status.success());
    assert!(general.stderr.is_empty());
    assert!(String::from_utf8(general.stdout)
        .unwrap()
        .contains("开启当前终端"));
    for language in ["en", "zh"] {
        let result = run(&["help", "advanced", language]);
        assert!(result.status.success());
        assert!(result.stderr.is_empty());
        let text = String::from_utf8(result.stdout).unwrap();
        assert!(text.contains("ptab complete-command <directory> <word-index> <words...>"));
        assert!(text.contains("--executables"));
    }
}

#[test]
fn invalid_help_arguments_are_diagnostics_not_candidates() {
    for args in [
        vec!["help", "fr"],
        vec!["--help", "unexpected"],
        vec!["help", "zh", "extra"],
        vec!["help", "advanced", "en", "extra"],
    ] {
        let result = run(&args);
        assert_eq!(result.status.code(), Some(2), "{args:?}");
        assert!(result.stdout.is_empty());
        assert!(String::from_utf8(result.stderr)
            .unwrap()
            .contains("ptab --help"));
    }
}

#[test]
fn shell_state_commands_require_the_loaded_integration() {
    for name in ["on", "off", "status"] {
        let result = run(&[name]);
        assert_eq!(result.status.code(), Some(2));
        assert!(result.stdout.is_empty());
        assert!(String::from_utf8(result.stderr)
            .unwrap()
            .contains("integration"));
    }
}

#[test]
fn info_commands_reject_extra_arguments() {
    for name in ["doctor", "version", "--version", "-V"] {
        let result = run(&[name, "unexpected"]);
        assert_eq!(result.status.code(), Some(2));
        assert!(result.stdout.is_empty());
        assert!(!result.stderr.is_empty());
    }
    for name in ["version", "--version", "-V"] {
        let result = run(&[name]);
        assert!(result.status.success());
        assert!(result.stderr.is_empty());
        assert_eq!(
            String::from_utf8(result.stdout).unwrap(),
            format!("PinyinTab {}\n", env!("CARGO_PKG_VERSION"))
        );
    }
}

#[test]
fn unknown_commands_return_actionable_usage_errors() {
    let result = run(&["does-not-exist"]);
    assert_eq!(result.status.code(), Some(2));
    assert!(result.stdout.is_empty());
    let message = String::from_utf8(result.stderr).unwrap();
    assert!(message.contains("unknown command"));
    assert!(message.contains("ptab --help"));
    #[cfg(unix)]
    {
        use std::ffi::OsString;
        use std::os::unix::ffi::OsStringExt;
        for args in [
            vec![OsString::from_vec(vec![0xff])],
            vec![OsString::from("help"), OsString::from_vec(vec![0xff])],
        ] {
            let result = Command::new(env!("CARGO_BIN_EXE_ptab"))
                .args(args)
                .output()
                .unwrap();
            assert_eq!(result.status.code(), Some(2));
            assert!(result.stdout.is_empty());
            assert!(!result.stderr.is_empty());
        }
    }
}

#[test]
fn update_rejects_arguments_and_never_updates_a_source_checkout() {
    let extra = run(&["update", "unexpected"]);
    assert_eq!(extra.status.code(), Some(2));
    assert!(extra.stdout.is_empty());
    let source = run(&["update"]);
    assert_eq!(source.status.code(), Some(1));
    assert!(source.stdout.is_empty());
    assert!(String::from_utf8(source.stderr)
        .unwrap()
        .contains("installed release"));
}

#[test]
fn installed_update_dispatches_its_own_helper_and_preserves_failure_status() {
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};
    let unique = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = std::env::temp_dir().join(format!(
        "pinyintab-cli-update-{}-{unique}",
        std::process::id()
    ));
    fs::create_dir(&root).unwrap();
    struct Cleanup(std::path::PathBuf);
    impl Drop for Cleanup {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }
    let _cleanup = Cleanup(root.clone());
    fs::create_dir(root.join("bin")).unwrap();
    fs::create_dir_all(root.join("share/pinyintab")).unwrap();
    let binary = root.join("bin/ptab");
    fs::copy(env!("CARGO_BIN_EXE_ptab"), &binary).unwrap();
    let invoke = || {
        Command::new(&binary)
            .arg("update")
            .env("PINYINTAB_INSTALL_ROOT", "/wrong-prefix")
            .env("UPDATE_EXPECTED_ROOT", &root)
            .output()
            .unwrap()
    };
    let missing = invoke();
    assert_eq!(missing.status.code(), Some(1));
    assert!(String::from_utf8(missing.stderr)
        .unwrap()
        .contains("updater is missing"));
    let helper = root.join("share/pinyintab/update.sh");
    fs::write(&helper, "test \"$PINYINTAB_INSTALL_ROOT\" = \"$UPDATE_EXPECTED_ROOT\" || exit 9\ntest \"$1\" = --update || exit 9\nprintf 'UPDATE_DISPATCH_OK\\n'\n").unwrap();
    let success = invoke();
    assert!(success.status.success());
    assert_eq!(success.stdout, b"UPDATE_DISPATCH_OK\n");
    fs::write(&helper, "exit 7\n").unwrap();
    assert_eq!(invoke().status.code(), Some(1));
}
