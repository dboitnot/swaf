pub mod policy;
pub mod session;

use crate::auth::{
    policy::{Effect, Group, PolicyStatement, PolicyStore},
    session::Session,
};
use crate::config::Config;
use crate::files;
use futures::executor;
use log::{info, warn};
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

pub struct RequestAuthorizor {
    username: String,
    policy_statements: Vec<PolicyStatement>,
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for RequestAuthorizor {
    type Error = ();

    async fn from_request(request: &'r Request<'_>) -> Outcome<RequestAuthorizor, ()> {
        let user = try_outcome!(request.guard::<Session>().await.map(|session| session.user));
        let policy_store = try_outcome!(executor::block_on(request.guard::<SessionPolicyStore>()));
        let policy_statements: Vec<PolicyStatement> = user
            .groups
            .iter()
            .map(|g| policy_store.group_named(g))
            .filter(|o| o.is_some())
            .flat_map(|o| o.unwrap().policy_statements.iter())
            .chain(user.policy_statements.iter())
            .cloned()
            .collect();
        Outcome::Success(RequestAuthorizor {
            username: user.login_name,
            policy_statements,
        })
    }
}

pub trait ToResourceId {
    fn to_resource_id(&self) -> Option<&str>;
}

impl ToResourceId for PathBuf {
    fn to_resource_id(&self) -> Option<&str> {
        self.to_str()
    }
}

impl RequestAuthorizor {
    fn result(self, r: Result<(), Status>) -> RequestAuthorizorResult {
        RequestAuthorizorResult {
            authorizor: self,
            result: r,
        }
    }

    pub fn require<R: ToResourceId + std::fmt::Debug>(
        self,
        action: &str,
        resource: &R,
    ) -> RequestAuthorizorResult {
        let resource_id = resource.to_resource_id();
        if resource_id.is_none() {
            warn!("Error extracting ID from resource: {:?}", resource);
            return self.result(Err(Status::InternalServerError));
        }
        let resource_id = resource_id.unwrap();
        let res = match self
            .policy_statements
            .iter()
            .map(|s| s.effect_on(action, resource_id))
            .filter(|o| o.is_some())
            .flatten()
            .reduce(|acc, e| if acc == Effect::Deny { acc } else { e })
        {
            Some(Effect::Allow) => Ok(()),
            _ => {
                info!(
                    "User '{}' is not authorized for '{}' on '{}'.",
                    self.username, action, resource_id
                );
                Err(Status::Unauthorized)
            }
        };
        self.result(res)
    }
}

pub struct RequestAuthorizorResult {
    authorizor: RequestAuthorizor,
    result: Result<(), Status>,
}

impl RequestAuthorizorResult {
    pub fn require<R: ToResourceId + std::fmt::Debug>(
        self,
        action: &str,
        resource: &R,
    ) -> RequestAuthorizorResult {
        if self.result.is_err() {
            return self;
        }
        self.authorizor.require(action, resource)
    }

    pub fn ok(self) -> Result<(), Status> {
        self.result
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
