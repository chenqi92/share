use crate::device::Device;
use crate::identity::Identity;
use crate::txt;
use anyhow::{Context, Result};
use log::{debug, info};
use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};
use std::collections::HashMap;
use std::net::TcpListener;
use std::sync::Arc;
use std::thread;

/// 同网段设备发现。Responder 与 Querier 一体。
///
/// 当前在专用线程里跑 mDNS 事件循环；通过 glib 通道把变更回送到 GTK 主线程。
pub struct Discovery {
    daemon: ServiceDaemon,
    fullname: String,
    _listener: TcpListener,         // 持有 TCP socket（骨架：accept 立即关）
}

impl Discovery {
    pub fn start<F>(
        identity: Arc<Identity>,
        display_name: String,
        model: Option<String>,
        on_change: F,
    ) -> Result<Self>
    where
        F: Fn(Vec<Device>) + Send + 'static,
    {
        let listener = TcpListener::bind("0.0.0.0:0").context("bind TCP")?;
        let port = listener.local_addr()?.port();

        {
            let listener_clone = listener.try_clone()?;
            thread::spawn(move || {
                for stream in listener_clone.incoming() {
                    match stream {
                        Ok(s) => {
                            debug!("incoming connection from {:?}; closing (skeleton)", s.peer_addr());
                            drop(s);
                        }
                        Err(_) => break,
                    }
                }
            });
        }

        let daemon = ServiceDaemon::new().context("create mDNS daemon")?;
        let props = txt::encode(&identity, &display_name, model.as_deref(), port, 1);

        let hostname = format!("{}.local.", identity.id);
        let info = ServiceInfo::new(
            txt::SERVICE_TYPE,
            &identity.id,           // instance name
            &hostname,
            "",                     // ips：留空配合 enable_addr_auto() 自动用所有接口
            port,
            Some(props),
        )
        .context("build ServiceInfo")?
        .enable_addr_auto();

        let fullname = format!("{}.{}", identity.id, txt::SERVICE_TYPE);

        daemon.register(info).context("register mDNS")?;
        info!("registered mDNS service: {} on port {}", fullname, port);

        // 浏览
        let receiver = daemon.browse(txt::SERVICE_TYPE).context("browse")?;
        let mut devices_map: HashMap<String, Device> = HashMap::new();
        let self_id = identity.id.clone();

        thread::spawn(move || {
            for event in receiver.iter() {
                match event {
                    ServiceEvent::ServiceResolved(info) => {
                        let attrs: HashMap<String, String> = info
                            .get_properties()
                            .iter()
                            .filter_map(|p| {
                                p.val_str().map(|v| (p.key().to_string(), v.to_string()))
                            })
                            .collect();
                        if let Some(device) = txt::decode(&attrs) {
                            if device.id == self_id { continue; }
                            devices_map.insert(device.id.clone(), device);
                            on_change(sorted(&devices_map));
                        }
                    }
                    ServiceEvent::ServiceRemoved(_ty, fullname) => {
                        let instance = fullname.split('.').next().unwrap_or("");
                        if devices_map.remove(instance).is_some() {
                            on_change(sorted(&devices_map));
                        }
                    }
                    other => debug!("mDNS event: {:?}", other),
                }
            }
        });

        Ok(Self {
            daemon,
            fullname,
            _listener: listener,
        })
    }

    pub fn stop(&self) {
        let _ = self.daemon.unregister(&self.fullname);
        let _ = self.daemon.shutdown();
    }
}

fn sorted(map: &HashMap<String, Device>) -> Vec<Device> {
    let mut v: Vec<Device> = map.values().cloned().collect();
    v.sort_by(|a, b| a.name.cmp(&b.name));
    v
}

