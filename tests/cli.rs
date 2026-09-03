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
