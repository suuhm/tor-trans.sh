#!/bin/bash
# ============================================================
#  TORTRANS.SH - Transparent Tor Proxy Management Script
#  Author: suuhm (c) 2025
# ============================================================

# ---------------- CONFIGURATION ----------------
TRANS_PORT="9040"
DNS_PORT="5353"
TOR_UID=$(id -u debian-tor 2>/dev/null || echo 999)
ALLOWED_TCP_PORTS="22"  # Allowed TCP ports (SSH default: 22)
BLOCK_IPV6=true
PWD="rottorrottor"
RESOLV_CONF="/etc/resolv.conf"
RESOLV_CONF_BACKUP="/etc/resolv.conf.backup.torproxy"
DNSMASQ_CONF="/etc/dnsmasq.d/tor-transparent.conf"

# ---------------- COLORS ----------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ---------------- ASCII BANNER ----------------
function banner() {
cat << "EOF"

████████╗ ██████╗ ═ ████╗ ████████╗██████╗  █████╗ ███╗   ██╗███████╗.sh
╚══██╔══╝██╔═══██╗██╔═══╝ ╚══██╔══╝██╔══██╗██╔══██╗████╗  ██║██╔════╝
   ██║   ██║║ ║██║██║        ██║   ██████╔╝███████║██╔██╗ ██║███████╗
   ██║   ██║ ═ ██║██║        ██║   ██╔══██╗██╔══██║██║╚██╗██║╚════██║
   ██║   ╚██████╔╝██║        ██║   ██║  ██║██║  ██║██║ ╚████║███████║
   ╚═ ═ ═ ══════╝ ╚═══  ═ ═ ═ ═╝ ══╚═╝ ═ ═╝╚══ ═ ═╝╚═╝  ╚═══╝╚══════╝
EOF
echo -e "${CYAN}Transparent Tor Proxy Control Script (c) 2025 by suuhm${NC}"
echo
}

# ---------------- FUNCTIONS ----------------
function setup_dnsmasq() {
  echo -e "${CYAN}[*] Launching dnsmasq with fixed configuration...${NC}"
  dnsmasq --port=53 \
          --interface=lo \
          --no-resolv \
          --server=127.0.0.1#${DNS_PORT} \
          --bogus-priv \
          --keep-in-foreground &
  echo $! > /var/run/torproxy-dnsmasq.pid
}

function set_resolvconf_to_local() {
  echo -e "${CYAN}[*] Setting ${RESOLV_CONF} to use local DNS (127.0.0.1)...${NC}"
  if [ ! -f "$RESOLV_CONF_BACKUP" ]; then
    sudo cp "$RESOLV_CONF" "$RESOLV_CONF_BACKUP"
  fi
  echo "nameserver 127.0.0.1" | sudo tee "$RESOLV_CONF" > /dev/null
}

function restore_resolvconf() {
  if [ -f "$RESOLV_CONF_BACKUP" ]; then
    echo -e "${CYAN}[*] Restoring original ${RESOLV_CONF}...${NC}"
    sudo mv "$RESOLV_CONF_BACKUP" "$RESOLV_CONF"
  else
    echo -e "${YELLOW}[!] No backup found. Cannot restore resolv.conf${NC}"
  fi
}

function start_tor_transparent_proxy() {
  echo -e "${GREEN}[*] Starting Transparent Tor Proxy...${NC}"
  
  # Clear old rules
  sudo iptables -F
  sudo iptables -t nat -F
  sudo iptables -t mangle -F
  sudo iptables -X
  
  if [ "$BLOCK_IPV6" = true ]; then
    sudo ip6tables -F
    sudo ip6tables -t nat -F
    sudo ip6tables -t mangle -F
    sudo ip6tables -X
  fi

  # Allow Tor process & loopback
  sudo iptables -t nat -A OUTPUT -m owner --uid-owner $TOR_UID -j RETURN
  sudo iptables -t nat -A OUTPUT -o lo -j RETURN
  
  for port in $ALLOWED_TCP_PORTS; do
    sudo iptables -t nat -A OUTPUT -p tcp --dport $port -j RETURN
  done

  # Allow private networks
  sudo iptables -t nat -A OUTPUT -d 127.0.0.1/32 -j RETURN
  sudo iptables -t nat -A OUTPUT -d 10.0.0.0/8 -j RETURN
  sudo iptables -t nat -A OUTPUT -d 172.16.0.0/12 -j RETURN
  sudo iptables -t nat -A OUTPUT -d 192.168.0.0/16 -j RETURN

  # Redirect traffic
  sudo iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports $TRANS_PORT
  sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT

  # Filtering rules
  sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  sudo iptables -A OUTPUT -o lo -j ACCEPT
  sudo iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport $TRANS_PORT -j ACCEPT
  
  for port in $ALLOWED_TCP_PORTS; do
    sudo iptables -A OUTPUT -p tcp --dport $port -j ACCEPT
  done
  sudo iptables -A OUTPUT -j DROP

  if [ "$BLOCK_IPV6" = true ]; then
    echo -e "${CYAN}[*] Blocking IPv6 traffic...${NC}"
    sudo ip6tables -P INPUT DROP
    sudo ip6tables -P FORWARD DROP
    sudo ip6tables -P OUTPUT DROP
  fi

  setup_dnsmasq
  set_resolvconf_to_local

  echo -e "${GREEN}✔ Transparent Tor routing is now ACTIVE${NC}"
}

function stop_tor_transparent_proxy() {
  echo -e "${YELLOW}[*] Stopping Transparent Tor Proxy...${NC}"
  
  sudo iptables -F
  sudo iptables -t nat -F
  sudo iptables -t mangle -F
  sudo iptables -X
  
  sudo ip6tables -F
  sudo ip6tables -t nat -F
  sudo ip6tables -t mangle -F
  sudo ip6tables -X
  sudo ip6tables -P INPUT ACCEPT
  sudo ip6tables -P FORWARD ACCEPT
  sudo ip6tables -P OUTPUT ACCEPT

  if [ -f /var/run/torproxy-dnsmasq.pid ]; then
    kill "$(cat /var/run/torproxy-dnsmasq.pid)" 2>/dev/null
    rm -f /var/run/torproxy-dnsmasq.pid
  fi

  restore_resolvconf
  echo -e "${RED}✘ Transparent Tor routing DISABLED${NC}"
}

function get_current_ip() {
  echo -e "\n${CYAN}[*] Checking current Tor exit IP...${NC}"
  local CURRENT_IP=$(curl --silent --max-time 10 https://check.torproject.org/api/ip)
  local IP_ONLY=$(echo "$CURRENT_IP" | grep -oP '(?<="IP":")[^"]+')
  if [ -n "$IP_ONLY" ]; then
    echo -e "${GREEN}Your Tor exit IP: ${IP_ONLY}${NC}"
  else
    echo -e "${RED}[!] Could not retrieve IP${NC}"
  fi
}

function renew_tor_ip_signal() {
  echo -e "${CYAN}[*] Sending signal to renew Tor IP (NEWNYM)...${NC}"
  local TOR_PID=$(pgrep -u debian-tor tor)
  if [ -z "$TOR_PID" ]; then
    echo -e "${RED}[!] Tor process not found${NC}"
    return 1
  fi
  kill -USR1 "$TOR_PID"
  echo -e "${GREEN}✔ Tor IP renewal signal sent${NC}"
}

function init_tor_control_config() {
  local TORRC="/etc/tor/torrc"
  local BACKUP="$TORRC.backup-$(date +%Y%m%d-%H%M%S)"
  local PASSWORD="$PWD"
  local HASH

  echo -e "${CYAN}[*] Backing up current torrc to $BACKUP${NC}"
  sudo cp "$TORRC" "$BACKUP" || { echo -e "${RED}[!] Backup failed. Aborting.${NC}"; return 1; }

  HASH=$(tor --hash-password "$PASSWORD" | tail -n1)
  if [ -z "$HASH" ]; then
    echo -e "${RED}[!] Could not generate password hash${NC}"
    return 1
  fi

  local CONFIG="
# Automatically set by init_tor_control_config on $(date)
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 9040
DNSPort 5353

ControlPort 9051
CookieAuthentication 0
HashedControlPassword $HASH
"

  sudo sed -i '/^VirtualAddrNetworkIPv4/d;/^AutomapHostsOnResolve/d;/^TransPort/d;/^DNSPort/d;/^ControlPort/d;/^CookieAuthentication/d;/^HashedControlPassword/d' "$TORRC"
  echo "$CONFIG" | sudo tee -a "$TORRC" > /dev/null

  echo -e "${GREEN}✔ New Tor configuration written to $TORRC${NC}"
  echo "$CONFIG"

  echo -e "${CYAN}[*] Restarting Tor service...${NC}"
  sudo systemctl restart tor
  sleep 2
  echo -e "${GREEN}✔ Tor restarted. New config is active${NC}"
}

function renew_tor_ip() {
  echo -e "${CYAN}[*] Requesting new Tor identity via ControlPort...${NC}"
  local response=$(echo -e "AUTHENTICATE \"$PWD\"\r\nSIGNAL NEWNYM\r\nQUIT\r\n" | nc 127.0.0.1 9051)
  echo "$response"
  if echo "$response" | grep -q "250 OK"; then
    echo -e "${GREEN}✔ New Tor IP successfully requested${NC}"
  else
    echo -e "${RED}[!] Failed to request new Tor IP${NC}"
    return 1
  fi
  sleep 3 && echo; get_current_ip
}

# ---------------- COMMAND DISPATCH ----------------
banner

case "$1" in
  start)
    start_tor_transparent_proxy
    ;;
  stop)
    stop_tor_transparent_proxy
    ;;
  restart)
    stop_tor_transparent_proxy; sleep 2 && start_tor_transparent_proxy
    ;;
  status)
    echo "= IPTABLES NAT-TABELLE ="
    sudo iptables -t nat -L -v
    echo "= IPTABLES FILTER-TABELLE ="
    sudo iptables -L -v
    get_current_ip
    ;;
  renew)
    renew_tor_ip
    ;;
  init)
    init_tor_control_config
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|renew|init}"
    exit 1
    ;;
esac

exit 0
