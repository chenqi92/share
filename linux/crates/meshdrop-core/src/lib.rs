//! MeshDrop 核心：协议、设备身份、mDNS 发现、TCP 传输、握手 + 文件传输引擎。
//!
//! GUI / TUI 都依赖这个 crate。

pub mod device;
pub mod identity;
pub mod txt;
pub mod discovery;
pub mod protocol;
pub mod history;
pub mod trust;
pub mod connection;
pub mod engine;
pub mod gateway;
mod resume;

pub use device::{Device, DeviceOS};
pub use identity::{compute_fingerprint, Identity};
pub use history::{HistoryItem, HistoryKind, TransferDirection, TransferStatus};
pub use trust::{TrustRecord, TrustStore};
pub use engine::{ShareEngine, PendingPairing, PendingFileOffer, PairingDecision, TransferMetrics, ClipboardEntry, SessionThroughput};
pub use gateway::{GatewayHandle, DEFAULT_PORT as GATEWAY_DEFAULT_PORT};
