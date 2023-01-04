use auth::{policy::User, session::Session, RequestAuthorizor};
use config::Config;
use rocket::fs::NamedFile;
use rocket::http::{Cookie, CookieJar};
use rocket::serde::json::Json;
use rocket::{fairing::AdHoc, Build, Rocket};
use std::path::{Path, PathBuf};
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

#[get("/file/<file..>")]
async fn get_file_data(authorizer: RequestAuthorizor, file: PathBuf) -> Option<NamedFile> {
    let auth_res = authorizer.require("file:ReadData", &file).ok();
    if auth_res.is_err() {
        return None;
    }
    // TODO: Remove hard-coded repo path
    NamedFile::open(Path::new("repo/file_root").join(file))
        .await
        .ok()
}

pub fn launch() -> Rocket<Build> {
    rocket::build()
        .mount("/", routes![health, user_current, login, get_file_data])
        .attach(AdHoc::config::<Config>())
}
