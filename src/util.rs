use std::time::{SystemTime, UNIX_EPOCH};
use wildflower::Pattern;

pub fn now_as_secs() -> Result<u64, ()> {
    let duration = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| ())?;
    Ok(duration.as_secs())
}

pub fn glob_matches(glob: &str, s: &str) -> bool {
    // For now we're just wrapping wildflower. We may want to improve on this.
    Pattern::new(glob).matches(s)
}
