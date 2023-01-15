use auth::session::{Session, SessionCookie};
use auth::FileChildren;
use auth::{policy::User, RequestedRegularFileDataReadable};
use config::Config;
use meta::FileMetadata;
use rocket::fs::NamedFile;
use rocket::http::{Cookie, CookieJar, Status};
use rocket::serde::json;
use rocket::serde::json::Json;
use rocket::{fairing::AdHoc, Build, Rocket};
use std::io::ErrorKind;
use std::path::{Path, PathBuf};
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
fn login(cookies: &CookieJar<'_>) -> Result<Json<User>, Status> {
    add_session_cookie(cookies)?;

    // TODO: Actually authenticate
    let user = User {
        login_name: String::from("fake"),
        full_name: Some(String::from("Fakie McFakeface")),
        groups: vec![String::from("fakers")],
        policy_statements: vec![],
    };
    Ok(Json(user))
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

#[get("/ls/<_..>")]
async fn get_file_children(children: FileChildren) -> Json<FileChildren> {
    Json(children)
}

#[get("/<file..>")]
async fn spa_files(mut file: PathBuf) -> Option<NamedFile> {
    if file.components().count() < 1 {
        file.push("index.html");
    }
    NamedFile::open(Path::new("spa/public/").join(file))
        .await
        .ok()
}

pub fn launch() -> Rocket<Build> {
    rocket::build()
        .mount(
            "/api",
            routes![
                health,
                user_current,
                login,
                get_file_data,
                get_file_meta,
                get_file_children
            ],
        )
        .mount("/", routes![spa_files])
        .attach(AdHoc::config::<Config>())
}
