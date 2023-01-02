use rocket::serde::Deserialize;
use std::path::PathBuf;

#[derive(Deserialize, Debug)]
#[serde(crate = "rocket::serde")]
pub struct Config {
    pub file_root: PathBuf,
}
