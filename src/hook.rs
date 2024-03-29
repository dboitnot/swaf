use log::{info, warn};
use std::ffi::OsStr;
use std::fs;
use std::io;
use std::path::Path;
use std::process::{Command, Stdio};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum HookError {
    #[error("hook invocation failed")]
    IoError(#[from] io::Error),

    #[error("hook exited with non-zero status")]
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
        .arg(path)
        .stdin(Stdio::null())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .spawn()?
        .wait()?;
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
    let paths = fs::read_dir(&dir)?
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().map(|t| t.is_file()).unwrap_or(false))
        .map(|e| e.path());
    for path in paths {
        let res = run_hook(&shell, path, env.clone());
        if let Err(ref e) = res {
            warn!("Hook error: {:?}\nAborting further hook processing.", e);
            return res;
        }
    }
    Ok(())
}
