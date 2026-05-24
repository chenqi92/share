//! 只管 mDNS 注册 + browse；TCP listener 由 ShareEngine 持有。

use crate::device::Device;
use crate::identity::Identity;
use crate::txt;
use anyhow::{Context, Result};
use log::{debug, info};
use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::watch;

pub struct DiscoveryHandle {
    daemon: ServiceDaemon,
    fullname: String,
    pub devices_rx: watch::Receiver<Vec<Device>>,
}

impl Drop for DiscoveryHandle {
    fn drop(&mut self) {
        let _ = self.daemon.unregister(&self.fullname);
        let _ = self.daemon.shutdown();
    }
}

pub fn start(
    identity: Arc<Identity>,
    display_name: String,
    model: Option<String>,
    port: u16,
) -> Result<DiscoveryHandle> {
    let daemon = ServiceDaemon::new().context("create mDNS daemon")?;
    let props = txt::encode(&identity, &display_name, model.as_deref(), port, 1);

    let hostname = format!("{}.local.", identity.id);
    let info = ServiceInfo::new(
        txt::SERVICE_TYPE,
        &identity.id,
        &hostname,
        "",
        port,
        Some(props),
    )
    .context("build ServiceInfo")?
    .enable_addr_auto();

    let fullname = format!("{}.{}", identity.id, txt::SERVICE_TYPE);
    daemon.register(info).context("register mDNS")?;
    info!("registered mDNS service: {} on port {}", fullname, port);

    let (devices_tx, devices_rx) = watch::channel(Vec::<Device>::new());
    let receiver = daemon.browse(txt::SERVICE_TYPE).context("browse")?;
    let self_id = identity.id.clone();

    // mdns-sd 是 sync API；专用线程跑事件循环，向 tokio watch 推送。
    std::thread::spawn(move || {
        let mut map: HashMap<String, Device> = HashMap::new();
        for event in receiver.iter() {
            match event {
                ServiceEvent::ServiceResolved(info) => {
                    let attrs: HashMap<String, String> = info.get_properties().iter()
                        .map(|p| (p.key().to_string(), p.val_str().to_string()))
                        .collect();
                    let mut device = match txt::decode(&attrs) {
                        Some(d) => d, None => continue,
                    };
                    if device.id == self_id { continue; }
                    let addr = info.get_addresses().iter().next().map(|a| a.to_string());
                    device.host = addr.or_else(|| Some(info.get_hostname().to_string()));
                    map.insert(device.id.clone(), device);
                    push_sorted(&devices_tx, &map);
                }
                ServiceEvent::ServiceRemoved(_, fullname) => {
                    let instance = fullname.split('.').next().unwrap_or("");
                    if map.remove(instance).is_some() {
                        push_sorted(&devices_tx, &map);
                    }
                }
                other => debug!("mDNS event: {:?}", other),
            }
        }
    });

    Ok(DiscoveryHandle { daemon, fullname, devices_rx })
}

fn push_sorted(tx: &watch::Sender<Vec<Device>>, map: &HashMap<String, Device>) {
    let mut v: Vec<Device> = map.values().cloned().collect();
    v.sort_by(|a, b| a.name.cmp(&b.name));
    let _ = tx.send(v);
}

// 也用 std::net 的非 tokio TcpListener 不行 — engine 用 tokio::net::TcpListener
#[allow(dead_code)]
fn _unused() {
    let _ = Arc::new(());
}
