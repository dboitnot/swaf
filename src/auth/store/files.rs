use crate::auth::policy::{Group, PolicyStatement, PolicyStore, User};
use fs2::FileExt;
use log::{info, warn};
use rocket::serde::json;
use rocket::serde::{Deserialize, DeserializeOwned, Serialize};
use std::env;
use std::fs;
use std::fs::{File, OpenOptions};
use std::io::Read;
use std::io::Write;
use std::path::{Path, PathBuf};

pub struct FilePolicyStore {
    user_dir: PathBuf,
    group_dir: PathBuf,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "rocket::serde")]
struct StoredUser {
    // Shared with policy::User
    login_name: String,
    full_name: Option<String>,
    groups: Vec<String>,
    policy_statements: Vec<PolicyStatement>,

    // Private
    password_hash: Option<String>,
}

impl From<StoredUser> for User {
    fn from(v: StoredUser) -> Self {
        User {
            login_name: v.login_name,
            full_name: v.full_name,
            groups: v.groups,
            policy_statements: v.policy_statements,
        }
    }
}

impl FilePolicyStore {
    pub fn new<P: AsRef<Path>>(base_dir: P) -> Result<FilePolicyStore, String> {
        let base_dir = base_dir.as_ref();
        let base_dir = if base_dir.is_absolute() {
            base_dir.to_owned()
        } else {
            env::current_dir()
                .map(|c| c.join(base_dir))
                .map_err(|_| format!("Invalid policy_store_root: {:?}", base_dir))?
        };
        check_dir("base", &base_dir)?;

        let store = FilePolicyStore {
            user_dir: base_dir.join("users"),
            group_dir: base_dir.join("groups"),
        };

        check_dir("user", &store.user_dir)?;
        check_dir("group", &store.user_dir)?;
        Ok(store)
    }
}

impl PolicyStore for FilePolicyStore {
    fn create_user(&self, user: &User) -> Result<(), ()> {
        store(
            &self.user_dir,
            &user.login_name,
            true,
            &StoredUser {
                login_name: user.login_name.clone(),
                full_name: user.full_name.clone(),
                groups: user.groups.clone(),
                policy_statements: user.policy_statements.clone(),
                password_hash: None,
            },
        )
        .map_err(|e| warn!("Error creating user: {:?}", e))
    }

    fn group_named(&self, name: &str) -> Option<Group> {
        load(&self.group_dir, name)
            .map_err(|e| warn!("Error loading group '{}': {:?}", name, e))
            .ok()
    }
}

fn check_dir<P: AsRef<Path>>(desc: &str, path: P) -> Result<(), String> {
    let path = path.as_ref();
    // let path = &path
    //     .canonicalize()
    //     .map_err(|_| format!("FilePolicyStore {} path is non-canonical: {:?}", desc, path))?;
    if !path.exists() {
        info!(
            "FilePolicyStore {} directory does not exist. Creating: {:?}",
            desc, path
        );
        fs::create_dir(path)
            .map_err(|e| format!("Error creating FilePolicyStore {} directory: {:?}", desc, e))?;
    }
    if !path.is_dir() {
        return Err(format!(
            "FilePolicyStore {} path is not a directory: {:?}",
            desc, path
        ));
    }
    Ok(())
}

enum OpenMode {
    Read,
    Update,
    Create,
}

fn with_file<O, T>(dir: &PathBuf, name: &'_ str, mode: OpenMode, op: O) -> Result<T, String>
where
    O: FnOnce(&File) -> Result<T, String>,
{
    let file_name = format!("{}.json", name);
    let path = dir.join(file_name);
    // let path = path
    //     .canonicalize()
    //     .map_err(|_| format!("Non-canonical data path: {:?}", path))?;
    if !path.starts_with(dir) {
        return Err(format!("Invalid object path: {:?}", path));
    }
    let mut options = OpenOptions::new();
    let exclusive = match mode {
        OpenMode::Read => {
            options.read(true);
            false
        }
        OpenMode::Update => {
            options.write(true).create(false).truncate(true);
            true
        }
        OpenMode::Create => {
            options.write(true).create_new(true);
            true
        }
    };
    let file = options
        .open(&path)
        .map_err(|e| format!("Error opening {:?}: {:?}", path, e))?;
    if exclusive {
        file.try_lock_exclusive()
            .map_err(|e| format!("Error locking {:?} exclusively: {:?}", path, e))?;
    } else {
        file.lock_shared()
            .map_err(|e| format!("Error locking {:?}: {:?}", path, e))?;
    }
    let ret = op(&file);
    file.unlock()
        .unwrap_or_else(|_| panic!("Failed to unlock {:?}", path));
    ret
}

fn load<T>(dir: &PathBuf, name: &'_ str) -> Result<T, String>
where
    T: DeserializeOwned,
{
    let mut buf = String::new();
    with_file(dir, name, OpenMode::Read, |mut f| {
        f.read_to_string(&mut buf)
            .map_err(|e| format!("Error reading {} in {:?}: {:?}", name, dir, e))?;
        json::from_str(buf.as_str())
            .map_err(|e| format!("Error decoding {} in {:?}: {:?}", name, dir, e))
    })
}

fn store<T>(dir: &PathBuf, name: &'_ str, create_new: bool, o: &T) -> Result<(), String>
where
    T: Serialize,
{
    let mode = if create_new {
        OpenMode::Create
    } else {
        OpenMode::Update
    };
    with_file(dir, name, mode, |mut f| {
        let s = json::to_pretty_string(o)
            .map_err(|e| format!("Error serializing {} in {:?}: {:?}", name, dir, e))?;
        f.write(s.as_bytes())
            .map_err(|e| format!("Error writing {} in {:?}: {:?}", name, dir, e))
            .map(|_| ())
    })
}
