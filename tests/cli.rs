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
