use std::time::{SystemTime, UNIX_EPOCH};

pub fn now_as_secs() -> Result<u64, ()> {
    let duration = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| ())?;
    Ok(duration.as_secs())
}
