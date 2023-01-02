use auth::policy::User;
use auth::session::Session;
use config::Config;
use rocket::http::{Cookie, CookieJar};
use rocket::serde::json::Json;
use rocket::{fairing::AdHoc, Build, Rocket};
use util::now_as_secs;

mod auth;
mod config;
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

pub fn launch() -> Rocket<Build> {
    rocket::build()
        .mount("/", routes![health, user_current, login])
        .attach(AdHoc::config::<Config>())
}
