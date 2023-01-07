mod authorizor;
pub mod policy;
pub mod session;

use crate::auth::authorizor::RequestAuthorizor;
use crate::auth::policy::{Group, PolicyStore};
use crate::config::Config;
use crate::files;
use rocket::http::Status;
use rocket::outcome::try_outcome;
use rocket::request::{FromRequest, Outcome, Request};
use rocket::State;
use std::path::PathBuf;

pub type SessionPolicyStore = Box<dyn PolicyStore>;

// Placeholder for actual policy store loading based on configuration.
struct SessionPolicyStoreImpl;

impl PolicyStore for SessionPolicyStoreImpl {
    fn group_named(&self, _name: &str) -> Option<&Group> {
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

pub struct RequestedFile {
    pub real_path: PathBuf,
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
        match files::realize(&config.file_root, &req_path, false) {
            Ok(real_path) => Outcome::Success(RequestedFile { real_path }),
            _ => Outcome::Failure((Status::BadRequest, "File realization failed")),
        }
    }
}

pub struct RequestedFileDataReadable {
    pub real_path: PathBuf,
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
            .require("file:ReadData", &file.real_path)
            .ok()
            .map(|_| {
                Outcome::Success(RequestedFileDataReadable {
                    real_path: file.real_path,
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
