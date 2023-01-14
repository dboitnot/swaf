use auth::session::{Session, SessionCookie};
use auth::{policy::User, RequestedRegularFileDataReadable};
use config::Config;
use meta::FileMetadata;
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
mod meta;
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

fn add_session_cookie(cookies: &CookieJar) -> Result<(), Status> {
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
    Ok(())
}

#[post("/login")]
fn login(cookies: &CookieJar<'_>) -> Result<&'static str, Status> {
    add_session_cookie(cookies)?;
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

#[get("/meta/<_..>")]
async fn get_file_meta(meta: FileMetadata) -> Json<FileMetadata> {
    Json(meta)
}

pub fn launch() -> Rocket<Build> {
    rocket::build()
        .mount(
            "/",
            routes![health, user_current, login, get_file_data, get_file_meta],
        )
        .attach(AdHoc::config::<Config>())
}
