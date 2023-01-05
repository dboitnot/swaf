use rocket::http::Status;
use rocket::outcome::{try_outcome, IntoOutcome};
use rocket::request::{FromRequest, Outcome, Request};
use rocket::serde::{json, Deserialize, Serialize};

use crate::auth::policy::{Effect, PolicyStatement, User};
use crate::util::now_as_secs;

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
        // TODO: Load user from store
        request
            .cookies()
            .get_private("session")
            .map(|cookie| String::from(cookie.value()))
            .and_then(|s| json::from_str::<SessionCookie>(s.as_str()).ok())
            .filter(|session| session.expires > now)
            .map(|_| Session {
                user: User {
                    login_name: String::from("fake"),
                    full_name: Some(String::from("Fakie McFakeface")),
                    groups: vec![String::from("fakers")],
                    policy_statements: vec![PolicyStatement {
                        effect: Effect::Allow,
                        actions: vec![String::from("*")],
                        resources: vec![String::from("*")],
                    }],
                },
            })
            .into_outcome((Status::Unauthorized, ()))
    }
}
