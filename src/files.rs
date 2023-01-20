use crate::config::Config;
use rocket::http::Status;
use rocket::outcome::{try_outcome, IntoOutcome};
use rocket::request::{FromRequest, Outcome, Request};
use rocket::State;
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

pub struct RequestedFile {
    pub real_path: PathBuf,
    pub logical_path: PathBuf,
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for RequestedFile {
    type Error = &'static str;

    async fn from_request(request: &'r Request<'_>) -> Outcome<RequestedFile, &'static str> {
        let config = try_outcome!(request
            .guard::<&State<Config>>()
            .await
            .map_failure(|_| (Status::InternalServerError, "Failed to retrieve config")));
        let req_path: PathBuf = match request.segments(1..) {
            Ok(path) => path,
            Err(_) => return Outcome::Failure((Status::BadRequest, "Invalid path")),
        };
        realize(&config.file_root, req_path, false)
            .map_err(|_| "Requested path did not realize")
            .into_outcome(Status::BadRequest)
    }
}

pub fn realize<B: AsRef<Path>, R: AsRef<Path>>(
    base_path: B,
    req_path: R,
    must_exist: bool,
) -> Result<RequestedFile, RealizationError> {
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
    let logical_path = real_path
        .strip_prefix(base_path)
        .map(|p| p.to_path_buf())
        .map_err(|_| RealizationError::OutsideBase)?;
    Ok(RequestedFile {
        real_path,
        logical_path,
    })
}
