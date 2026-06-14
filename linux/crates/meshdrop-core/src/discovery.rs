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
    /// 缓存注册信息，供 `set_advertising(true)` 重新广告时复用（避免重建 daemon）。
    service_info: ServiceInfo,
    /// 当前是否在广告 mDNS。关广告只 unregister 服务，daemon / browse 不动，
    /// 已建连接也不强断（仅"不再被发现"）。
    advertising: bool,
    pub devices_rx: watch::Receiver<Vec<Device>>,
}

impl DiscoveryHandle {
    /// 局域网可见开关：true=广告 mDNS（可被发现）；false=停止广告（不再被发现，
    /// 但 browse 仍在、已建连接不强断）。幂等：重复设同值无副作用。
    /// 见 desktop SOON「局域网可见 visibleOnLan」。
    pub fn set_advertising(&mut self, enabled: bool) {
        if enabled == self.advertising {
            return;
        }
        if enabled {
            // 重新注册：复用启动时构造的 ServiceInfo。
            if self.daemon.register(self.service_info.clone()).is_ok() {
                self.advertising = true;
                info!("mDNS advertising resumed: {}", self.fullname);
            }
        } else {
            let _ = self.daemon.unregister(&self.fullname);
            self.advertising = false;
            info!("mDNS advertising paused: {}", self.fullname);
        }
    }

    pub fn is_advertising(&self) -> bool {
        self.advertising
    }
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
    daemon.register(info.clone()).context("register mDNS")?;
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

    Ok(DiscoveryHandle { daemon, fullname, service_info: info, advertising: true, devices_rx })
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
