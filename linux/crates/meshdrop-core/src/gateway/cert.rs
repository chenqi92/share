//! 自签证书：CN=meshdrop.local。首次启动用 rcgen 生成，落到 config_dir。

use anyhow::{Context, Result};
use log::info;
use rcgen::{CertificateParams, DistinguishedName, DnType, KeyPair, SanType};
use std::fs;
use std::io::BufReader;
use std::path::{Path, PathBuf};
use tokio_rustls::rustls::pki_types::{CertificateDer, PrivateKeyDer};

pub struct GatewayCert {
    pub cert_chain: Vec<CertificateDer<'static>>,
    pub key: PrivateKeyDer<'static>,
}

pub fn load_or_generate(dir: &Path) -> Result<GatewayCert> {
    fs::create_dir_all(dir).context("create gateway cert dir")?;
    let cert_path = dir.join("cert.pem");
    let key_path = dir.join("key.pem");

    if cert_path.exists() && key_path.exists() {
        if let Ok(cert) = load_existing(&cert_path, &key_path) {
            return Ok(cert);
        }
        info!("gateway cert files exist but parse failed — regenerating");
    }

    generate(&cert_path, &key_path)
}

fn load_existing(cert_path: &Path, key_path: &Path) -> Result<GatewayCert> {
    // 既有 key.pem 也强制收紧到 0600（兼容早期版本写出的宽权限文件）。
    set_key_permissions(key_path)?;
    let cert_pem = fs::read(cert_path)?;
    let key_pem = fs::read(key_path)?;
    let cert_chain = rustls_pemfile::certs(&mut BufReader::new(&cert_pem[..]))
        .collect::<std::result::Result<Vec<_>, _>>()
        .context("parse cert.pem")?;
    if cert_chain.is_empty() {
        anyhow::bail!("cert.pem 无证书");
    }
    let key = rustls_pemfile::private_key(&mut BufReader::new(&key_pem[..]))
        .context("parse key.pem")?
        .context("key.pem 无私钥")?;
    Ok(GatewayCert { cert_chain, key })
}

fn generate(cert_path: &PathBuf, key_path: &PathBuf) -> Result<GatewayCert> {
    let mut params = CertificateParams::new(vec!["meshdrop.local".into(), "localhost".into()])
        .context("CertificateParams")?;
    params.subject_alt_names.push(SanType::DnsName("meshdrop.local".try_into()?));
    params.subject_alt_names.push(SanType::DnsName("localhost".try_into()?));
    let mut dn = DistinguishedName::new();
    dn.push(DnType::CommonName, "meshdrop.local");
    dn.push(DnType::OrganizationName, "MeshDrop");
    params.distinguished_name = dn;
    let key_pair = KeyPair::generate().context("rcgen KeyPair")?;
    let cert = params.self_signed(&key_pair).context("rcgen self_signed")?;

    let cert_pem = cert.pem();
    let key_pem = key_pair.serialize_pem();
    fs::write(cert_path, &cert_pem).context("write cert.pem")?;
    fs::write(key_path, &key_pem).context("write key.pem")?;
    // 私钥仅本机可读：chmod 0600，防同机其他用户读取 Gateway TLS 私钥。
    set_key_permissions(key_path)?;
    info!("generated self-signed gateway cert at {}", cert_path.display());

    let cert_chain = rustls_pemfile::certs(&mut BufReader::new(cert_pem.as_bytes()))
        .collect::<std::result::Result<Vec<_>, _>>()
        .context("re-parse generated cert")?;
    let key = rustls_pemfile::private_key(&mut BufReader::new(key_pem.as_bytes()))
        .context("parse generated key")?
        .context("missing key")?;
    Ok(GatewayCert { cert_chain, key })
}

/// 把私钥文件权限收紧到 0600（仅 Unix；其它平台无操作）。
#[cfg(unix)]
fn set_key_permissions(key_path: &Path) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    let perms = fs::Permissions::from_mode(0o600);
    fs::set_permissions(key_path, perms).context("chmod 0600 key.pem")?;
    Ok(())
}

#[cfg(not(unix))]
fn set_key_permissions(_key_path: &Path) -> Result<()> {
    Ok(())
}
