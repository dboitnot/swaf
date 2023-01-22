use rocket::serde::Deserialize;
use std::path::PathBuf;

#[derive(Deserialize, Debug, Clone)]
#[serde(crate = "rocket::serde")]
pub struct Config {
    pub file_root: PathBuf,
    pub policy_store_root: PathBuf,
}
