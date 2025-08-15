# Tor-TRANS.sh
A user-friendly, colorful, and fully-featured Bash script for managing a transparent Tor proxy on Linux. Includes status reporting, DNS redirection via dnsmasq, IPv6 blocking, Tor ControlPort integration, IP renewal, and easy start/stop/restart commands.

<img width="441" height="413" alt="grafik" src="https://github.com/user-attachments/assets/39bde6ab-dde6-4823-8549-742039351c8f" />


## Features

- 🎨 **Colorful & user-friendly CLI** with clear status messages
- 🔀 **Transparent Tor routing** with `iptables` redirection
- 🔒 **IPv6 traffic blocking** for privacy
- 🌐 **DNS redirection via dnsmasq**
- 📜 **Automatic `resolv.conf` backup & restore**
- 🔄 **Start, stop, restart, and status commands**
- 🔑 **Tor ControlPort integration**:
  - Renew Tor IP via signal or ControlPort command
  - Initialize Tor config with hashed password
- 🕵 **Check your current Tor exit IP**
- 💾 Backup of Tor configuration before changes

---

>
> <img width="623" height="288" alt="grafik" src="https://github.com/user-attachments/assets/8eb87fbc-801c-40e6-84de-d2b6557a369f" />



---

## Requirements

- Linux (Debian/Ubuntu recommended)
- `tor`
- `iptables` and `ip6tables`
- `dnsmasq`
- `curl`
- `netcat` (`nc`)

---

## Installation

```bash
git clone https://github.com/suuhm/tor-trans.sh
cd tor-trans.sh
chmod +x tor-trans.sh
````

---

## Usage

>[!IMPORTANT]
> At the first start you have to run `./tor-trans.sh init`
>
> <img width="700" height="403" alt="grafik" src="https://github.com/user-attachments/assets/35095ab1-1ade-4337-990e-e0ee63dcfc23" />



```bash
./tor-trans.sh {command}
```

**Available Commands:**

| Command        | Description                              |
| -------------- | ---------------------------------------- |
| `start`        | Start transparent Tor proxy              |
| `stop`         | Stop transparent Tor proxy               |
| `restart`      | Restart transparent Tor proxy            |
| `status`       | Show iptables rules and current Tor IP   |
| `renew`        | Request new Tor IP via ControlPort       |
| `init`         | Initialize Tor ControlPort configuration |

---

### Example

```bash
# Start Tor transparent proxy
./tor-trans.sh start

# Check status
./tor-trans.sh status

# Get a new Tor identity via ControlPort
./tor-trans.sh renew
```

---

## How It Works

* All outgoing TCP traffic is transparently redirected to Tor's `TransPort` using `iptables`
* All DNS queries are redirected to Tor's `DNSPort` via `dnsmasq`
* IPv6 is optionally blocked to prevent leaks
* A backup of `/etc/resolv.conf` is kept and restored when stopped
* Tor ControlPort can be configured to allow programmatic IP renewal

---

## Security Notes

* This script modifies your system's firewall and DNS settings.
* Always review the script before running it on a production machine.
* IPv6 blocking is recommended to prevent leaks.

---

## License

MIT License – feel free to modify and share.


