use auth::Session;
use policy::User;
use rocket::http::{Cookie, CookieJar};
use rocket::serde::json::Json;
use util::now_as_secs;

mod auth;
mod policy;
mod util;

#[macro_use]
extern crate rocket;

#[get("/health")]
fn health() -> &'static str {
    "Healthy."
}

#[get("/user/current")]
fn user_current(session: Session) -> Json<User> {
    Json(session.user)
}

#[post("/login")]
fn login(cookies: &CookieJar<'_>) -> Result<&'static str, ()> {
    let exp = now_as_secs()
        .map(|now| now + 300)
        .map(|n| n.to_string())
        .map_err(|_| ())?;
    cookies.add_private(Cookie::new("session_expires", exp));
    Ok("Ok")
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![health, user_current, login])
}
