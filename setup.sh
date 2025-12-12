#!/bin/bash
clear
echo "🚀 RDP-SERVER: Cloudflare Tunnel Proxmox (Automático)"
echo "================================================================"

command -v pct >/dev/null 2>&1 || { echo "❌ HOST Proxmox Shell!"; exit 1; }

IP_CT=$(ip -4 route get 1 | awk '{print $7}' | head -1)
IP_BASE=${IP_CT%.*}
GATEWAY=$(ip route | grep default | awk '{print $3}')
CTID=999

read -p "☁️  Nome do Túnel: " TUNNEL_NAME
read -p "🌐 Domínio: " DOMINIO
IP_VM_UBUNTU="${IP_BASE}.10"
IP_VM_WINDOWS="${IP_BASE}.20"

echo "Config: ubuntu.$DOMINIO → $IP_VM_UBUNTU:22 | windows.$DOMINIO → $IP_VM_WINDOWS:3389"
read -p "OK? (s/N): " OK && [[ $OK =~ ^[Ss] ]] || exit

# ✅ BAIXA TEMPLATE UBUNTU 22.04 PRIMEIRO
echo "📥 Baixando Ubuntu 22.04..."
pveam update
pveam download local ubuntu-22.04-standard_22.04-2_amd64.tar.zst

# ✅ LIMPA CT
pct status $CTID >/dev/null 2>&1 && pct stop $CTID && pct destroy $CTID

# ✅ USA TEMPLATE CORRETO: ubuntu-22.04-standard_22.04-2_amd64.tar.zst
echo "🐳 Criando CT..."
pct create $CTID local:vztmpl/ubuntu-22.04-standard_22.04-2_amd64.tar.zst \
  --hostname cloudflare-rdp --cores 1 --memory 512 \
  --net0 "name=eth0,bridge=vmbr0,ip=$IP_CT/24,gw=$GATEWAY" \
  --rootfs local-lvm:4 --unprivileged 1 --features nesting=1

pct start $CTID && sleep 30

# ✅ pct exec CORRETO (uma linha por comando)
echo "☁️  Cloudflare..."
pct exec $CTID -- apt update -y
pct exec $CTID -- apt install curl sudo -y
pct exec $CTID -- bash -c "curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cf.deb && dpkg -i /tmp/cf.deb"
pct exec $CTID -- cloudflared tunnel login
pct exec $CTID -- cloudflared tunnel create $TUNNEL_NAME
pct exec $CTID -- cloudflared tunnel route dns $TUNNEL_NAME ubuntu.$DOMINIO
pct exec $CTID -- cloudflared tunnel route dns $TUNNEL_NAME windows.$DOMINIO
pct exec $CTID -- cloudflared service install
pct exec $CTID -- systemctl restart cloudflared

echo "✅ PRONTO! Autorize no browser Cloudflare"
echo "Cloudflare > Tunnels > $TUNNEL_NAME > Add Hostnames:"
echo "• ubuntu.$DOMINIO → $IP_VM_UBUNTU:22 (TCP)"
echo "• windows.$DOMINIO → $IP_VM_WINDOWS:3389 (TCP)"
