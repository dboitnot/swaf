use crate::auth::{
    policy::{Effect, PolicyStatement},
    session::Session,
    SessionPolicyStore,
};
use crate::meta::MetadataAuthorizor;
use futures::executor;
use log::{info, warn};
use rocket::http::Status;
use rocket::outcome::try_outcome;
use rocket::request::{FromRequest, Outcome, Request};
use std::path::{Path, PathBuf};

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

impl<P: AsRef<Path>> ToResourceId for P {
    fn to_resource_id(&self) -> Option<&str> {
        self.as_ref().to_str()
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
        let res = if self.is_allowed(action, resource) {
            Ok(())
        } else {
            Err(Status::Forbidden)
        };
        self.result(res)
    }

    pub fn is_allowed<R: ToResourceId + std::fmt::Debug>(
        &self,
        action: &str,
        resource: &R,
    ) -> bool {
        let resource_id = resource.to_resource_id();
        if resource_id.is_none() {
            warn!("Error extracting ID from resource: {:?}", resource);
            return false;
        }
        let resource_id = resource_id.unwrap();
        match self
            .policy_statements
            .iter()
            .map(|s| s.effect_on(action, resource_id))
            .filter(|o| o.is_some())
            .flatten()
            .reduce(|acc, e| if acc == Effect::Deny { acc } else { e })
        {
            Some(Effect::Allow) => true,
            _ => {
                info!(
                    "User '{}' is not authorized for '{}' on '{}'.",
                    self.username, action, resource_id
                );
                false
            }
        }
    }
}

impl MetadataAuthorizor for RequestAuthorizor {
    fn may_read_file(&self, logical_path: PathBuf) -> bool {
        self.is_allowed("file:Read", &logical_path)
    }
    fn may_write_file(&self, logical_path: PathBuf) -> bool {
        self.is_allowed("file:Write", &logical_path)
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
