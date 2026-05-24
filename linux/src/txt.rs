use crate::device::{Device, DeviceOS};
use crate::identity::Identity;
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use std::collections::HashMap;

pub const SERVICE_TYPE: &str = "_meshdrop._tcp.local.";

pub fn encode(
    identity: &Identity,
    display_name: &str,
    model: Option<&str>,
    port: u16,
    protocol_version: u8,
) -> HashMap<String, String> {
    let mut map = HashMap::new();
    map.insert("v".into(), protocol_version.to_string());
    map.insert("id".into(), identity.id.clone());
    map.insert("name".into(), URL_SAFE_NO_PAD.encode(display_name.as_bytes()));
    map.insert("os".into(), DeviceOS::CURRENT.as_str().into());
    map.insert("fp".into(), identity.fingerprint.clone());
    map.insert("port".into(), port.to_string());
    if let Some(m) = model {
        map.insert("model".into(), m.into());
    }
    map
}

pub fn decode(attrs: &HashMap<String, String>) -> Option<Device> {
    let v: u8 = attrs.get("v")?.parse().ok()?;
    let id = attrs.get("id")?;
    if id.len() != 32 { return None; }
    let name_b64 = attrs.get("name")?;
    let name_bytes = URL_SAFE_NO_PAD.decode(name_b64).ok()?;
    let name = String::from_utf8(name_bytes).ok()?;
    let os = DeviceOS::parse(attrs.get("os")?)?;
    let fp = attrs.get("fp")?;
    if fp.len() != 32 { return None; }
    let port: u16 = attrs.get("port")?.parse().ok()?;

    Some(Device {
        id: id.clone(),
        name,
        os,
        model: attrs.get("model").cloned(),
        fingerprint: fp.clone(),
        port,
        protocol_version: v,
    })
}
