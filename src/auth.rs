mod authorizor;
pub mod policy;
pub mod session;
pub mod store;

use crate::auth::authorizor::RequestAuthorizor;
use crate::auth::policy::{Group, PolicyStore, User};
use crate::files::RequestedFile;
use crate::meta::{file_children, metadata_for_file, FileMetadata};
use rocket::http::Status;
use rocket::outcome::try_outcome;
use rocket::request::{FromRequest, Outcome, Request};
use rocket::serde::Serialize;
use std::path::PathBuf;

pub type SessionPolicyStore = Box<dyn PolicyStore>;

// Placeholder for actual policy store loading based on configuration.
struct SessionPolicyStoreImpl;

impl PolicyStore for SessionPolicyStoreImpl {
    fn create_user(&self, _user: &User) -> Result<(), ()> {
        Ok(())
    }
    fn group_named(&self, _name: &str) -> Option<Group> {
        None
    }
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for SessionPolicyStore {
    type Error = ();

    async fn from_request(_request: &'r Request<'_>) -> Outcome<SessionPolicyStore, ()> {
        Outcome::Success(Box::new(SessionPolicyStoreImpl {}))
    }
}

pub struct RequestedFileDataReadable {
    pub real_path: PathBuf,
    pub logical_path: PathBuf,
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for RequestedFileDataReadable {
    type Error = &'static str;

    async fn from_request(
        request: &'r Request<'_>,
    ) -> Outcome<RequestedFileDataReadable, &'static str> {
        let file = try_outcome!(request.guard::<RequestedFile>().await);
        let authorizor = try_outcome!(request
            .guard::<RequestAuthorizor>()
            .await
            .map_failure(|(s, _)| (s, "No session authorizor")));
        authorizor
            .require("file:Read", &file.real_path) // TODO: I think this should be the logical_path
            .ok()
            .map(|_| {
                Outcome::Success(RequestedFileDataReadable {
                    real_path: file.real_path,
                    logical_path: file.logical_path,
                })
            })
            .unwrap_or_else(|e| Outcome::Failure((e, "Access Denied")))
    }
}

pub struct RequestedFileDataWritable {
    pub real_path: PathBuf,
    pub logical_path: PathBuf,
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for RequestedFileDataWritable {
    type Error = &'static str;

    async fn from_request(
        request: &'r Request<'_>,
    ) -> Outcome<RequestedFileDataWritable, &'static str> {
        let file = try_outcome!(request.guard::<RequestedFile>().await);
        let authorizor = try_outcome!(request
            .guard::<RequestAuthorizor>()
            .await
            .map_failure(|(s, _)| (s, "No session authorizor")));
        authorizor
            .require("file:Write", &file.real_path) // TODO: I think this should be the logical_path
            .ok()
            .map(|_| {
                Outcome::Success(RequestedFileDataWritable {
                    real_path: file.real_path,
                    logical_path: file.logical_path,
                })
            })
            .unwrap_or_else(|e| Outcome::Failure((e, "Access Denied")))
    }
}

pub struct RequestedRegularFileDataReadable {
    pub real_path: PathBuf,
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for RequestedRegularFileDataReadable {
    type Error = &'static str;

    async fn from_request(
        request: &'r Request<'_>,
    ) -> Outcome<RequestedRegularFileDataReadable, &'static str> {
        request
            .guard::<RequestedFileDataReadable>()
            .await
            .and_then(|f| {
                if f.real_path.is_file() {
                    Outcome::Success(RequestedRegularFileDataReadable {
                        real_path: f.real_path,
                    })
                } else {
                    Outcome::Failure((
                        Status::NotFound,
                        "Requested path does not exist or is not a regular file.",
                    ))
                }
            })
    }
}

pub struct RequestedDirectoryWritable {
    pub real_path: PathBuf,
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for RequestedDirectoryWritable {
    type Error = &'static str;

    async fn from_request(
        request: &'r Request<'_>,
    ) -> Outcome<RequestedDirectoryWritable, &'static str> {
        request
            .guard::<RequestedFileDataWritable>()
            .await
            .and_then(|f| {
                if f.real_path.is_file() {
                    Outcome::Success(RequestedDirectoryWritable {
                        real_path: f.real_path,
                    })
                } else {
                    Outcome::Failure((
                        Status::NotFound,
                        "Requested path does not exist or is not a directory.",
                    ))
                }
            })
    }
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for FileMetadata {
    type Error = &'static str;

    async fn from_request(request: &'r Request<'_>) -> Outcome<FileMetadata, &'static str> {
        let authorizor = try_outcome!(request
            .guard::<RequestAuthorizor>()
            .await
            .map_failure(|(s, _)| (s, "No session authorizor")));
        let file = try_outcome!(request.guard::<RequestedFile>().await);
        if !authorizor.is_allowed("file:Read", &file.logical_path) {
            return Outcome::Failure((Status::Forbidden, "Access Denied"));
        };
        match metadata_for_file(&file.real_path, &file.logical_path, &authorizor) {
            Ok(m) => Outcome::Success(m),
            Err(e) => {
                warn!("Error fetching metadata for {:?}: {:?}", file.real_path, e);
                Outcome::Failure((Status::InternalServerError, "Internal Error"))
            }
        }
    }
}

#[derive(Serialize)]
#[serde(crate = "rocket::serde")]
pub struct FileChildren {
    pub children: Vec<FileMetadata>,
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for FileChildren {
    type Error = &'static str;

    async fn from_request(request: &'r Request<'_>) -> Outcome<FileChildren, &'static str> {
        let authorizor = try_outcome!(request
            .guard::<RequestAuthorizor>()
            .await
            .map_failure(|(s, _)| (s, "No session authorizor")));
        let file = try_outcome!(request.guard::<RequestedFile>().await);
        if !authorizor.is_allowed("file:Read", &file.logical_path) {
            return Outcome::Failure((Status::Forbidden, "Access Denied"));
        };
        match file_children(&file.real_path, &file.logical_path, &authorizor) {
            Ok(children) => Outcome::Success(FileChildren { children }),
            Err(e) => {
                warn!("Error fetching metadata for {:?}: {:?}", file.real_path, e);
                Outcome::Failure((Status::InternalServerError, "Internal Error"))
            }
        }
    }
}
