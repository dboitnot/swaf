use log::{info, warn};
use std::ffi::OsStr;
use std::fs;
use std::io;
use std::path::Path;
use std::process::{Command, Stdio};

pub enum HookError {
    IoError(io::Error),
    BadExitStatus,
}

fn run_hook<S, P, I, K, V>(shell: S, path: P, envs: I) -> Result<(), HookError>
where
    S: AsRef<OsStr>,
    P: AsRef<Path>,
    I: IntoIterator<Item = (K, V)>,
    K: AsRef<OsStr>,
    V: AsRef<OsStr>,
{
    let path = path.as_ref();
    info!("Executing hook: {:?}", path);
    let status = Command::new(shell)
        .env_remove("ROCKET_SECRET_KEY")
        .envs(envs)
        .stdin(Stdio::null())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .spawn()
        .map_err(HookError::IoError)?
        .wait()
        .map_err(HookError::IoError)?;
    match status.code() {
        Some(0) => {
            info!("Hook {:?} exited with status: 0", path);
            Ok(())
        }
        Some(n) => {
            info!("Hook {:?} exited with status: {}", path, n);
            Err(HookError::BadExitStatus)
        }
        None => {
            info!(
                "Hook {:?} exited without status. It might have been killed by signal.",
                path
            );
            Err(HookError::BadExitStatus)
        }
    }
}

pub fn run_hooks<S, P, T, K, V>(
    shell: S,
    hook_root: P,
    hook_type: T,
    env: Vec<(K, V)>,
) -> Result<(), HookError>
where
    S: AsRef<OsStr>,
    P: AsRef<Path>,
    T: AsRef<OsStr>,
    K: AsRef<OsStr> + Clone,
    V: AsRef<OsStr> + Clone,
{
    let dir = hook_root.as_ref().join(hook_type.as_ref());
    if !dir.exists() {
        debug!("No hook directory: {:?}", dir);
        return Ok(());
    };
    let paths = fs::read_dir(&dir)
        .map_err(HookError::IoError)?
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().map(|t| t.is_file()).unwrap_or(false))
        .map(|e| dir.join(e.path()));
    for path in paths {
        let res = run_hook(&shell, path, env.clone());
        if res.is_err() {
            warn!("Aborting further hook processing.");
            return res;
        }
    }
    Ok(())
}
