use fuser::{
    FileAttr, FileType, Filesystem, MountOption, ReplyAttr, ReplyData, ReplyDirectory, ReplyEntry,
    ReplyOpen, Request,
};
use pinfs_demo::{Aliases, NameMapper};
use std::collections::HashMap;
use std::ffi::{OsStr, OsString};
use std::fs::{self, File, Metadata};
use std::io::{self, Read, Seek, SeekFrom};
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::time::{Duration, UNIX_EPOCH};

const TTL: Duration = Duration::from_secs(1);

#[derive(Clone)]
struct Node {
    path: PathBuf,
    parent: u64,
}

struct Child {
    path: PathBuf,
    real_name: OsString,
    visible_name: OsString,
    aliases: Aliases,
}

pub fn preview(source: &Path) -> io::Result<()> {
    preview_dir(source, source)
}

fn preview_dir(root: &Path, current: &Path) -> io::Result<()> {
    let mapper = NameMapper;
    let mut entries: Vec<_> = fs::read_dir(current)?.collect::<Result<_, _>>()?;
    entries.sort_by_key(|entry| entry.file_name());
    for entry in entries {
        let path = entry.path();
        let name = entry.file_name();
        let name = name
            .to_str()
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "non-UTF-8 filename"))?;
        let aliases = mapper.aliases(name);
        println!(
            "{} -> {} (initials: {})",
            path.strip_prefix(root).unwrap_or(&path).display(),
            aliases.full,
            aliases.initials
        );
        if entry.file_type()?.is_dir() {
            preview_dir(root, &path)?;
        }
    }
    Ok(())
}

pub fn mount(source: &Path, mountpoint: &Path) -> io::Result<()> {
    let source = source.canonicalize()?;
    if !source.is_dir() || !mountpoint.is_dir() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "source and mountpoint must be existing directories",
        ));
    }
    if fs::read_dir(mountpoint)?.next().transpose()?.is_some() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "mountpoint must be empty",
        ));
    }

    fuser::mount2(
        PinFs::new(source),
        mountpoint,
        &[
            MountOption::RO,
            MountOption::FSName("pinfs-demo".into()),
            MountOption::DefaultPermissions,
        ],
    )
}

struct PinFs {
    mapper: NameMapper,
    nodes: HashMap<u64, Node>,
    inode_by_path: HashMap<PathBuf, u64>,
    next_inode: u64,
}

impl PinFs {
    fn new(root: PathBuf) -> Self {
        Self {
            mapper: NameMapper,
            nodes: HashMap::from([(
                1,
                Node {
                    path: root.clone(),
                    parent: 1,
                },
            )]),
            inode_by_path: HashMap::from([(root, 1)]),
            next_inode: 2,
        }
    }

    fn inode_for(&mut self, path: PathBuf, parent: u64) -> u64 {
        if let Some(inode) = self.inode_by_path.get(&path) {
            return *inode;
        }
        let inode = self.next_inode;
        self.next_inode += 1;
        self.nodes.insert(
            inode,
            Node {
                path: path.clone(),
                parent,
            },
        );
        self.inode_by_path.insert(path, inode);
        inode
    }

    fn children(&self, parent: u64) -> io::Result<Vec<Child>> {
        let parent_path = &self
            .nodes
            .get(&parent)
            .ok_or_else(|| io::Error::from_raw_os_error(libc::ENOENT))?
            .path;
        let mut entries: Vec<_> = fs::read_dir(parent_path)?.collect::<Result<_, _>>()?;
        entries.sort_by_key(|entry| entry.file_name());

        let mut children = Vec::new();
        let mut counts: HashMap<String, usize> = HashMap::new();
        for entry in entries {
            let real_name = entry.file_name();
            let text = real_name
                .to_str()
                .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "non-UTF-8 filename"))?;
            let aliases = self.mapper.aliases(text);
            *counts.entry(aliases.full.clone()).or_default() += 1;
            children.push(Child {
                path: entry.path(),
                real_name,
                visible_name: OsString::from(&aliases.full),
                aliases,
            });
        }

        let mut seen: HashMap<String, usize> = HashMap::new();
        for child in &mut children {
            if counts[&child.aliases.full] > 1 {
                let number = seen.entry(child.aliases.full.clone()).or_default();
                *number += 1;
                child.visible_name = OsString::from(with_suffix(&child.aliases.full, *number));
            }
        }
        Ok(children)
    }

    fn resolve(&mut self, parent: u64, name: &OsStr) -> Result<u64, i32> {
        let typed = name.to_str().ok_or(libc::EINVAL)?;
        let children = self.children(parent).map_err(errno)?;
        let matches: Vec<_> = children
            .iter()
            .filter(|child| {
                name == child.real_name.as_os_str()
                    || name == child.visible_name.as_os_str()
                    || typed == child.aliases.initials
            })
            .collect();
        match matches.as_slice() {
            [child] => Ok(self.inode_for(child.path.clone(), parent)),
            [] => Err(libc::ENOENT),
            _ => Err(libc::EEXIST),
        }
    }

    fn attr(&self, inode: u64) -> Result<FileAttr, i32> {
        let node = self.nodes.get(&inode).ok_or(libc::ENOENT)?;
        let metadata = fs::symlink_metadata(&node.path).map_err(errno)?;
        Ok(to_attr(inode, &metadata))
    }
}

impl Filesystem for PinFs {
    fn lookup(&mut self, _req: &Request<'_>, parent: u64, name: &OsStr, reply: ReplyEntry) {
        match self
            .resolve(parent, name)
            .and_then(|inode| self.attr(inode))
        {
            Ok(attr) => reply.entry(&TTL, &attr, 0),
            Err(code) => reply.error(code),
        }
    }

    fn getattr(&mut self, _req: &Request<'_>, inode: u64, reply: ReplyAttr) {
        match self.attr(inode) {
            Ok(attr) => reply.attr(&TTL, &attr),
            Err(code) => reply.error(code),
        }
    }

    fn readdir(
        &mut self,
        _req: &Request<'_>,
        inode: u64,
        _fh: u64,
        offset: i64,
        mut reply: ReplyDirectory,
    ) {
        let parent = match self.nodes.get(&inode) {
            Some(node) => node.parent,
            None => {
                reply.error(libc::ENOENT);
                return;
            }
        };
        let children = match self.children(inode) {
            Ok(value) => value,
            Err(error) => {
                reply.error(errno(error));
                return;
            }
        };
        let mut entries = vec![
            (inode, FileType::Directory, OsString::from(".")),
            (parent, FileType::Directory, OsString::from("..")),
        ];
        for child in children {
            let child_inode = self.inode_for(child.path.clone(), inode);
            let metadata = match fs::symlink_metadata(&child.path) {
                Ok(value) => value,
                Err(_) => continue,
            };
            entries.push((child_inode, kind(&metadata), child.visible_name));
        }
        for (index, (child_inode, file_type, name)) in
            entries.into_iter().enumerate().skip(offset as usize)
        {
            if reply.add(child_inode, (index + 1) as i64, file_type, name) {
                break;
            }
        }
        reply.ok();
    }

    fn open(&mut self, _req: &Request<'_>, inode: u64, flags: i32, reply: ReplyOpen) {
        if flags & libc::O_ACCMODE != libc::O_RDONLY {
            reply.error(libc::EROFS);
            return;
        }
        match self.attr(inode) {
            Ok(attr) if attr.kind == FileType::RegularFile => reply.opened(0, 0),
            Ok(_) => reply.error(libc::EACCES),
            Err(code) => reply.error(code),
        }
    }

    fn read(
        &mut self,
        _req: &Request<'_>,
        inode: u64,
        _fh: u64,
        offset: i64,
        size: u32,
        _flags: i32,
        _lock_owner: Option<u64>,
        reply: ReplyData,
    ) {
        let result = (|| -> io::Result<Vec<u8>> {
            let node = self
                .nodes
                .get(&inode)
                .ok_or_else(|| io::Error::from_raw_os_error(libc::ENOENT))?;
            let mut file = File::open(&node.path)?;
            file.seek(SeekFrom::Start(offset.max(0) as u64))?;
            let mut bytes = vec![0; size as usize];
            let count = file.read(&mut bytes)?;
            bytes.truncate(count);
            Ok(bytes)
        })();
        match result {
            Ok(bytes) => reply.data(&bytes),
            Err(error) => reply.error(errno(error)),
        }
    }
}

fn with_suffix(name: &str, number: usize) -> String {
    match name.rsplit_once('.') {
        Some((stem, extension)) if !stem.is_empty() => format!("{stem}~{number}.{extension}"),
        _ => format!("{name}~{number}"),
    }
}

fn kind(metadata: &Metadata) -> FileType {
    if metadata.is_dir() {
        FileType::Directory
    } else if metadata.file_type().is_symlink() {
        FileType::Symlink
    } else {
        FileType::RegularFile
    }
}

fn to_attr(inode: u64, metadata: &Metadata) -> FileAttr {
    FileAttr {
        ino: inode,
        size: metadata.len(),
        blocks: metadata.blocks(),
        atime: metadata.accessed().unwrap_or(UNIX_EPOCH),
        mtime: metadata.modified().unwrap_or(UNIX_EPOCH),
        ctime: metadata.modified().unwrap_or(UNIX_EPOCH),
        crtime: UNIX_EPOCH,
        kind: kind(metadata),
        perm: (metadata.mode() & 0o7777) as u16,
        nlink: metadata.nlink() as u32,
        uid: metadata.uid(),
        gid: metadata.gid(),
        rdev: metadata.rdev() as u32,
        flags: 0,
        blksize: metadata.blksize() as u32,
    }
}

fn errno(error: io::Error) -> i32 {
    error.raw_os_error().unwrap_or(libc::EINVAL)
}
