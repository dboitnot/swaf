use rocket::http::Status;
use rocket::outcome::{try_outcome, IntoOutcome};
use rocket::request::{FromRequest, Outcome, Request};

use crate::policy::User;
use crate::util::now_as_secs;

pub struct Session {
    pub user: User,
    pub expires: u64,
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for User {
    type Error = ();

    async fn from_request(_request: &'r Request<'_>) -> Outcome<User, ()> {
        Outcome::Success(User {
            login_name: String::from("fake"),
            full_name: Some(String::from("Fakie McFakeface")),
            is_admin: true,
            groups: vec![String::from("fakers")],
            policy_statements: vec![],
        })
    }
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for Session {
    type Error = ();

    async fn from_request(request: &'r Request<'_>) -> Outcome<Session, ()> {
        let user = try_outcome!(request.guard::<User>().await);
        let now = try_outcome!(now_as_secs().into_outcome(Status::InternalServerError));
        request
            .cookies()
            .get_private("session_expires")
            .and_then(|cookie| cookie.value().parse().ok())
            .and_then(|exp| {
                if exp > now {
                    Some(Session { user, expires: exp })
                } else {
                    None
                }
            })
            .into_outcome((Status::Unauthorized, ()))
    }
}
