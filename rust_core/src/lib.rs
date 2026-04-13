use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::OnceLock;
use std::thread;

use arti_client::{TorClient, TorClientConfig};
use tor_rtcompat::PreferredRuntime;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

/// 0 = not running/unavailable, 1 = connecting, 2 = ready.
static TOR_STATE: AtomicU8 = AtomicU8::new(0);

static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();

#[no_mangle]
pub extern "C" fn arti_bootstrap() -> u8 {
    // Start only once.
    let prev = TOR_STATE.compare_exchange(0, 1, Ordering::SeqCst, Ordering::SeqCst);
    if prev.is_err() {
        // Already started/starting/ready.
        return 1;
    }

    // Build a Tokio runtime once and keep it alive for the app lifetime.
    let rt = match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .thread_name("arti-tokio")
        .build()
    {
        Ok(rt) => rt,
        Err(_) => {
            TOR_STATE.store(0, Ordering::SeqCst);
            return 0;
        }
    };
    let _ = RUNTIME.set(rt);

    // Spawn a dedicated OS thread that blocks on the runtime.
    thread::spawn(|| {
        let rt = match RUNTIME.get() {
            Some(rt) => rt,
            None => {
                TOR_STATE.store(0, Ordering::SeqCst);
                return;
            }
        };

        rt.block_on(async {
            // Create and bootstrap Tor client.
            let cfg = TorClientConfig::default();
            let builder = TorClient::builder_from_config(cfg);

            let client = match builder.create_unbootstrapped().await {
                Ok(c) => c,
                Err(_) => {
                    TOR_STATE.store(0, Ordering::SeqCst);
                    return;
                }
            };

            let client = match client.bootstrap().await {
                Ok(c) => c,
                Err(_) => {
                    TOR_STATE.store(0, Ordering::SeqCst);
                    return;
                }
            };

            // Bind SOCKS5 listener.
            let listener = match TcpListener::bind("127.0.0.1:9050").await {
                Ok(l) => l,
                Err(_) => {
                    TOR_STATE.store(0, Ordering::SeqCst);
                    return;
                }
            };

            TOR_STATE.store(2, Ordering::SeqCst);

            loop {
                let (sock, _) = match listener.accept().await {
                    Ok(v) => v,
                    Err(_) => continue,
                };
                let client = client.clone();
                tokio::spawn(async move {
                    let _ = handle_socks5(sock, client).await;
                });
            }
        });
    });

    1
}

/// Backward-compatible symbol for existing Dart bridge.
#[no_mangle]
pub extern "C" fn arti_is_ready() -> u8 {
    if TOR_STATE.load(Ordering::SeqCst) == 2 {
        1
    } else {
        0
    }
}

/// New symbol requested by spec: returns bool (as u8 for C ABI).
#[no_mangle]
pub extern "C" fn is_tor_ready() -> u8 {
    arti_is_ready()
}

async fn handle_socks5(mut sock: TcpStream, tor: TorClient<PreferredRuntime>) -> std::io::Result<()> {
    // ---- handshake ----
    // client: VER, NMETHODS, METHODS...
    let ver = sock.read_u8().await?;
    if ver != 0x05 {
        return Ok(());
    }
    let nmethods = sock.read_u8().await? as usize;
    let mut methods = vec![0u8; nmethods];
    sock.read_exact(&mut methods).await?;

    // choose "no authentication" (0x00) if offered.
    if !methods.iter().any(|m| *m == 0x00) {
        // no acceptable methods
        sock.write_all(&[0x05, 0xFF]).await?;
        return Ok(());
    }
    sock.write_all(&[0x05, 0x00]).await?;

    // ---- request ----
    // VER, CMD, RSV, ATYP, DST.ADDR, DST.PORT
    let req_ver = sock.read_u8().await?;
    if req_ver != 0x05 {
        return Ok(());
    }
    let cmd = sock.read_u8().await?;
    let _rsv = sock.read_u8().await?;
    let atyp = sock.read_u8().await?;

    if cmd != 0x01 {
        // only CONNECT supported
        reply_socks5(&mut sock, 0x07, SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 0)).await?;
        return Ok(());
    }

    let (host, ip_addr_opt) = match atyp {
        0x01 => {
            // IPv4
            let mut b = [0u8; 4];
            sock.read_exact(&mut b).await?;
            let ip = IpAddr::V4(Ipv4Addr::from(b));
            (None, Some(ip))
        }
        0x03 => {
            // domain
            let len = sock.read_u8().await? as usize;
            let mut b = vec![0u8; len];
            sock.read_exact(&mut b).await?;
            let s = String::from_utf8_lossy(&b).to_string();
            (Some(s), None)
        }
        0x04 => {
            // IPv6
            let mut b = [0u8; 16];
            sock.read_exact(&mut b).await?;
            let ip = IpAddr::V6(Ipv6Addr::from(b));
            (None, Some(ip))
        }
        _ => {
            reply_socks5(&mut sock, 0x08, SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 0)).await?;
            return Ok(());
        }
    };

    let port = sock.read_u16().await?;

    // Create Tor stream.
    let tor_stream = if let Some(host) = host {
        match tor.connect((host.as_str(), port)).await {
            Ok(s) => s,
            Err(_) => {
                reply_socks5(&mut sock, 0x05, SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 0)).await?;
                return Ok(());
            }
        }
    } else if let Some(ip) = ip_addr_opt {
        match tor.connect((ip, port)).await {
            Ok(s) => s,
            Err(_) => {
                reply_socks5(&mut sock, 0x05, SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 0)).await?;
                return Ok(());
            }
        }
    } else {
        reply_socks5(&mut sock, 0x01, SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 0)).await?;
        return Ok(());
    };

    // success reply with dummy bound addr.
    reply_socks5(&mut sock, 0x00, SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 0)).await?;

    // Pipe bytes both directions.
    let (mut a, mut b) = (sock, tor_stream);
    let _ = tokio::io::copy_bidirectional(&mut a, &mut b).await;
    Ok(())
}

async fn reply_socks5(sock: &mut TcpStream, rep: u8, bind: SocketAddr) -> std::io::Result<()> {
    // VER, REP, RSV, ATYP, BND.ADDR, BND.PORT
    match bind.ip() {
        IpAddr::V4(ip) => {
            let mut resp = Vec::with_capacity(10);
            resp.push(0x05);
            resp.push(rep);
            resp.push(0x00);
            resp.push(0x01);
            resp.extend_from_slice(&ip.octets());
            resp.extend_from_slice(&bind.port().to_be_bytes());
            sock.write_all(&resp).await?;
        }
        IpAddr::V6(ip) => {
            let mut resp = Vec::with_capacity(22);
            resp.push(0x05);
            resp.push(rep);
            resp.push(0x00);
            resp.push(0x04);
            resp.extend_from_slice(&ip.octets());
            resp.extend_from_slice(&bind.port().to_be_bytes());
            sock.write_all(&resp).await?;
        }
    }
    Ok(())
}

