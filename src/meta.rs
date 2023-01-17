use log::warn;
use rocket::serde::{Deserialize, Serialize};
use std::io::Error;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(crate = "rocket::serde")]
pub struct FileMetadata {
    pub path: PathBuf, // TODO: Should this be &Path?
    pub parent: Option<PathBuf>,
    pub file_name: Option<String>,
    pub is_dir: bool,
    pub may_read: bool,
    pub may_write: bool,
    pub modified: Option<u128>,
    pub size_bytes: Option<u64>,
}

pub trait MetadataAuthorizor {
    fn may_read_file(&self, logical_path: PathBuf) -> bool;
    fn may_write_file(&self, logical_path: PathBuf) -> bool;
}

// TODO: How do we handle directories with large numbers of files?
pub fn metadata_for_file<P>(
    real_path: P,
    logical_path: P,
    authorizor: &dyn MetadataAuthorizor,
) -> Result<FileMetadata, Error>
where
    P: AsRef<Path>,
{
    let real_path = real_path.as_ref();
    let logical_path = logical_path.as_ref();
    let is_dir = real_path.is_dir();
    Ok(FileMetadata {
        path: logical_path.to_path_buf(),
        parent: logical_path.parent().map(|p| p.to_path_buf()),
        file_name: logical_path
            .file_name()
            .and_then(|o| o.to_str())
            .map(String::from),
        is_dir,
        may_read: authorizor.may_read_file(logical_path.to_path_buf()),
        may_write: authorizor.may_write_file(logical_path.to_path_buf()),
        modified: real_path
            .metadata()
            .and_then(|m| m.modified())
            .ok()
            .and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok())
            .map(|d| d.as_millis()),
        size_bytes: real_path.metadata().ok().map(|m| m.len()),
    })
}

pub fn file_children<P>(
    real_path: P,
    logical_path: P,
    authorizor: &dyn MetadataAuthorizor,
) -> Result<Vec<FileMetadata>, Error>
where
    P: AsRef<Path>,
{
    let real_path = real_path.as_ref();
    let logical_path = logical_path.as_ref();
    let dir_entry_it = real_path.read_dir()?;
    Ok(dir_entry_it
        .map(|r| {
            if r.is_err() {
                warn!("Error reading children of {:?}: {:?}", &real_path, r)
            };
            r
        })
        .filter(|r| r.is_ok())
        .flatten()
        .map(|e| e.path())
        .map(|p| {
            (
                p.clone(),
                logical_path.join(
                    p.strip_prefix(real_path)
                        .expect("failure stripping parent from child path"),
                ),
            )
        })
        .flat_map(|(r, l)| match metadata_for_file(&r, &l, authorizor) {
            Ok(m) => Some(m),
            Err(e) => {
                warn!("Error reading child metadata of {:?}: {:?}", r, e);
                None
            }
        })
        .collect())
}
