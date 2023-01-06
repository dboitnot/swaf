use std::io::{Error, ErrorKind};
use std::path::{Path, PathBuf};

pub enum RealizationError {
    NonCanonicalBase(Error),
    NonCanonicalParent(Error),
    NonCanonicalPath(Error),
    FileNotFound,
    ParentNotFound,
    OutsideBase,
}

pub fn realize<P: AsRef<Path>>(
    base_path: P,
    req_path: P,
    must_exist: bool,
) -> Result<PathBuf, RealizationError> {
    let base_path = base_path
        .as_ref()
        .canonicalize()
        .map_err(RealizationError::NonCanonicalBase)?;
    let real_path = base_path.join(req_path);
    let real_path: PathBuf = match real_path.try_exists() {
        Ok(true) => real_path
            .canonicalize()
            .map_err(RealizationError::NonCanonicalPath),
        Ok(false) => {
            if must_exist {
                return Err(RealizationError::FileNotFound);
            } else {
                // The file doesn't exist but it doesn't have to. So canonicalize
                // the parent and then re-join.
                let parent_path = real_path.parent().ok_or(RealizationError::ParentNotFound)?;
                let parent_path = match parent_path.canonicalize() {
                    Ok(path) => Ok(path),
                    Err(e) if e.kind() == ErrorKind::NotFound => {
                        Err(RealizationError::ParentNotFound)
                    }
                    Err(e) => Err(RealizationError::NonCanonicalParent(e)),
                }?;
                real_path
                    .file_name()
                    .ok_or(RealizationError::OutsideBase)
                    .map(|f| parent_path.join(f))
            }
        }
        Err(e) => Err(RealizationError::NonCanonicalPath(e)),
    }?;
    if real_path.starts_with(base_path) {
        Ok(real_path)
    } else {
        Err(RealizationError::OutsideBase)
    }
}
