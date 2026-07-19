# Security Policy

## Supported versions

Security fixes are applied to the latest released minor version. Pre-1.0 releases may change shell integration behavior between minor versions.

## Reporting a vulnerability

Do not open a public issue for a suspected shell-injection, path-disclosure, unsafe installer, or archive-integrity problem. Use GitHub's private security advisory feature after the repository is published. Include the PinyinTab version, `ptab doctor` output, a minimized reproduction, and the affected shell.

## Trust boundary

PinyinTab reads names from a local directory and prints candidates to Bash or Zsh. It does not execute a completed file and does not use the network during completion. The installer changes the current user's shell startup file only inside marked lines and creates a backup before the first change.

Treat filenames as untrusted input. Changes involving quoting, control characters, newlines, command substitution, or escape sequences require regression tests in both the Rust core and shell integration.
