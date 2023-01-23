use rocket::http::Status;
use rocket::outcome::{try_outcome, IntoOutcome};
use rocket::request::{FromRequest, Outcome, Request};
use rocket::serde::{json, Deserialize, Serialize};
use rocket::State;

use crate::auth::policy::{PolicyStore, User};
use crate::util::now_as_secs;

use super::store::files::FilePolicyStore;

#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "rocket::serde")]
pub struct SessionCookie {
    pub username: String,
    pub expires: u64,
}

#[derive(Debug)]
pub struct Session {
    pub user: User,
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for Session {
    type Error = ();

    async fn from_request(request: &'r Request<'_>) -> Outcome<Self, Self::Error> {
        let now = try_outcome!(now_as_secs().into_outcome(Status::InternalServerError));
        let policy_store = try_outcome!(request.guard::<&State<FilePolicyStore>>().await);
        let policy_store = policy_store.inner();
        // TODO: Load user from store
        request
            .cookies()
            .get_private("session")
            .map(|cookie| String::from(cookie.value()))
            .and_then(|s| json::from_str::<SessionCookie>(s.as_str()).ok())
            .filter(|session| session.expires > now)
            .map(|s| policy_store.user_named(&s.username))
            .filter(|r| r.is_ok())
            .map(|r| r.unwrap())
            .map(|user| Session { user })
            .into_outcome((Status::Unauthorized, ()))
    }
}
