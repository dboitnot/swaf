use auth::session::{Session, SessionCookie};
use auth::{policy::User, RequestedRegularFileDataReadable};
use config::Config;
use rocket::fs::NamedFile;
use rocket::http::{Cookie, CookieJar, Status};
use rocket::serde::json;
use rocket::serde::json::Json;
use rocket::{fairing::AdHoc, Build, Rocket};
use std::io::ErrorKind;
use util::now_as_secs;

mod auth;
mod config;
mod files;
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
fn login(cookies: &CookieJar<'_>) -> Result<&'static str, Status> {
    // TODO: Actually load the user from store
    let exp = now_as_secs()
        .map(|now| now + 300)
        .map_err(|_| Status::InternalServerError)?;
    let session_cookie = SessionCookie {
        username: String::from("fake"),
        expires: exp,
    };
    let session_cookie =
        json::to_string(&session_cookie).map_err(|_| Status::InternalServerError)?;
    cookies.add_private(Cookie::new("session", session_cookie));
    Ok("Ok")
}

#[get("/file/<_..>")]
async fn get_file_data(file: RequestedRegularFileDataReadable) -> Result<NamedFile, Status> {
    NamedFile::open(file.real_path)
        .await
        .map_err(|e| match e.kind() {
            ErrorKind::NotFound => Status::NotFound,
            _ => Status::InternalServerError,
        })
}

pub fn launch() -> Rocket<Build> {
    rocket::build()
        .mount("/", routes![health, user_current, login, get_file_data])
        .attach(AdHoc::config::<Config>())
}
