pub mod policy;
pub mod session;

use crate::auth::{
    policy::{Effect, Group, PolicyStatement, PolicyStore},
    session::Session,
};
use futures::executor;
use rocket::http::Status;
use rocket::outcome::try_outcome;
use rocket::request::{FromRequest, Outcome, Request};
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
        Outcome::Success(RequestAuthorizor { policy_statements })
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

    pub fn require<R: ToResourceId>(self, action: &str, resource: &R) -> RequestAuthorizorResult {
        let resource_id = resource.to_resource_id();
        if resource_id.is_none() {
            return self.result(Err(Status::InternalServerError));
        }
        let res = match self
            .policy_statements
            .iter()
            .map(|s| s.effect_on(action, resource_id.unwrap()))
            .filter(|o| o.is_some())
            .flatten()
            .reduce(|acc, e| if acc == Effect::Deny { acc } else { e })
        {
            Some(Effect::Allow) => Ok(()),
            _ => Err(Status::Unauthorized),
        };
        self.result(res)
    }
}

pub struct RequestAuthorizorResult {
    authorizor: RequestAuthorizor,
    result: Result<(), Status>,
}

impl RequestAuthorizorResult {
    pub fn require<R: ToResourceId>(self, action: &str, resource: &R) -> RequestAuthorizorResult {
        self.authorizor.require(action, resource)
    }

    pub fn ok(self) -> Result<(), Status> {
        self.result
    }
}
