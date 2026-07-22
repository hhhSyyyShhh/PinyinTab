//! Core library for PinyinTab.
//!
//! The shell integrations collect the current command-line word and ask this
//! crate for real filesystem candidates. Pinyin is only a query language: the
//! returned value is always the real filename or directory name.

#![forbid(unsafe_code)]

pub mod cli;
pub mod completion;
mod diagnostics;
mod mapper;

#[cfg(test)]
mod test_support;

pub use mapper::{Aliases, NameMapper};
