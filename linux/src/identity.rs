use anyhow::{Context, Result};
use ed25519_dalek::{SigningKey, VerifyingKey};
use rand::rngs::OsRng;
use sha2::{Digest, Sha256};
use std::fs;
use std::path::PathBuf;
use uuid::Uuid;

/// 设备身份。Ed25519 长期密钥 + UUID。
///
/// v0.1 骨架：私钥裸落 `~/.local/share/MeshDrop/ed25519.bin`。
/// v1.0 要切到 libsecret (org.freedesktop.secrets)。
pub struct Identity {
    pub id: String,                    // 32 hex
    pub signing_key: SigningKey,
    pub fingerprint: String,           // 32 hex
}

impl Identity {
    pub fn load_or_create() -> Result<Self> {
        let dir = storage_dir()?;
        fs::create_dir_all(&dir).context("create storage dir")?;
        let id_path = dir.join("id");
        let key_path = dir.join("ed25519.bin");

        if id_path.exists() && key_path.exists() {
            let id = fs::read_to_string(&id_path)?.trim().to_string();
            let key_bytes = fs::read(&key_path)?;
            let arr: [u8; 32] = key_bytes
                .as_slice()
                .try_into()
                .context("private key length != 32")?;
            let signing_key = SigningKey::from_bytes(&arr);
            let fingerprint = compute_fingerprint(&signing_key.verifying_key());
            return Ok(Self { id, signing_key, fingerprint });
        }

        let id = Uuid::new_v4().simple().to_string();   // 32 hex 小写
        let signing_key = SigningKey::generate(&mut OsRng);
        fs::write(&id_path, &id)?;
        fs::write(&key_path, signing_key.to_bytes())?;
        // 仅当前用户可读
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(&key_path)?.permissions();
            perms.set_mode(0o600);
            fs::set_permissions(&key_path, perms)?;
        }
        let fingerprint = compute_fingerprint(&signing_key.verifying_key());
        Ok(Self { id, signing_key, fingerprint })
    }

    pub fn verifying_key(&self) -> VerifyingKey {
        self.signing_key.verifying_key()
    }
}

pub fn compute_fingerprint(verifying_key: &VerifyingKey) -> String {
    let raw = verifying_key.to_bytes();
    let hash = Sha256::digest(raw);
    hex::encode(&hash[..16])
}

fn storage_dir() -> Result<PathBuf> {
    let base = dirs::data_local_dir().context("no XDG data dir")?;
    Ok(base.join("MeshDrop"))
}
