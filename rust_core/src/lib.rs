use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::OnceLock;
use std::thread;

use arti_client::{TorClient, TorClientConfig};
use tor_rtcompat::PreferredRuntime;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

/// Состояния: 0 - стоп, 1 - запуск, 2 - готов
static TOR_STATE: AtomicU8 = AtomicU8::new(0);
static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();

#[no_mangle]
pub extern "C" fn arti_bootstrap() -> u8 {
    let prev = TOR_STATE.compare_exchange(0, 1, Ordering::SeqCst, Ordering::SeqCst);
    if prev.is_err() {
        return 1; 
    }

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

    thread::spawn(|| {
        let rt = match RUNTIME.get() {
            Some(rt) => rt,
            None => return,
        };

        rt.block_on(async {
            let cfg = TorClientConfig::default();
            
            // Пытаемся создать и запустить клиент Tor
            let client_res = async {
                let unbootstrapped = TorClient::builder().config(cfg).create_unbootstrapped()?;
                let bootstrapped = unbootstrapped.bootstrap().await?;
                Ok::<TorClient<PreferredRuntime>, arti_client::Error>(bootstrapped)
            }.await;

            if let Ok(final_client) = client_res {
                // Пытаемся запустить TCP Listener для SOCKS5
                if let Ok(listener) = TcpListener::bind("127.0.0.1:9050").await {
                    TOR_STATE.store(2, Ordering::SeqCst);

                    loop {
                        if let Ok((sock, _)) = listener.accept().await {
                            let client_clone = final_client.clone();
                            tokio::spawn(async move {
                                let _ = handle_socks5(sock, client_clone).await;
                            });
                        }
                    }
                } else {
                    TOR_STATE.store(0, Ordering::SeqCst);
                }
            } else {
                TOR_STATE.store(0, Ordering::SeqCst);
            }
        });
    });

    1
}

#[no_mangle]
pub extern "C" fn arti_is_ready() -> u8 {
    if TOR_STATE.load(Ordering::SeqCst) == 2 { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn is_tor_ready() -> u8 {
    arti_is_ready()
}

async fn handle_socks5(mut sock: TcpStream, tor: TorClient<PreferredRuntime>) -> std::io::Result<()> {
    let mut header = [0u8; 2];
    sock.read_exact(&mut header).await?;
    if header[0] != 0x05 { return Ok(()); }
    
    let nmethods = header[1] as usize;
    let mut methods = vec![0u8; nmethods];
    sock.read_exact(&mut methods).await?;

    if !methods.contains(&0x00) {
        sock.write_all(&[0x05, 0xFF]).await?;
        return Ok(());
    }
    sock.write_all(&[0x05, 0x00]).await?;

    let mut cmd_head = [0u8; 4];
    sock.read_exact(&mut cmd_head).await?;
    if cmd_head[1] != 0x01 { 
        reply_socks5(&mut sock, 0x07, SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 0)).await?;
        return Ok(());
    }

    let (host, port) = match cmd_head[3] {
        0x01 => {
            let mut b = [0u8; 4];
            sock.read_exact(&mut b).await?;
            let p = sock.read_u16().await?;
            (IpAddr::V4(Ipv4Addr::from(b)).to_string(), p)
        }
        0x03 => {
            let len = sock.read_u8().await? as usize;
            let mut b = vec![0u8; len];
            sock.read_exact(&mut b).await?;
            let p = sock.read_u16().await?;
            (String::from_utf8_lossy(&b).to_string(), p)
        }
        0x04 => {
            let mut b = [0u8; 16];
            sock.read_exact(&mut b).await?;
            let p = sock.read_u16().await?;
            (IpAddr::V6(Ipv6Addr::from(b)).to_string(), p)
        }
        _ => return Ok(()),
    };

    match tor.connect((host, port)).await {
        Ok(tor_stream) => {
            reply_socks5(&mut sock, 0x00, SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 0)).await?;
            let (mut a, mut b) = (sock, tor_stream);
            let _ = tokio::io::copy_bidirectional(&mut a, &mut b).await;
        }
        Err(_) => {
            let _ = reply_socks5(&mut sock, 0x05, SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 0)).await;
        }
    }
    Ok(())
}

async fn reply_socks5(sock: &mut TcpStream, rep: u8, bind: SocketAddr) -> std::io::Result<()> {
    let mut resp = vec![0x05, rep, 0x00];
    match bind.ip() {
        IpAddr::V4(ip) => {
            resp.push(0x01);
            resp.extend_from_slice(&ip.octets());
        }
        IpAddr::V6(ip) => {
            resp.push(0x04);
            resp.extend_from_slice(&ip.octets());
        }
    }
    resp.extend_from_slice(&bind.port().to_be_bytes());
    sock.write_all(&resp).await
}