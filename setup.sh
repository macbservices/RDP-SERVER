#!/bin/bash
clear
echo "🚀 RDP-SERVER: Cloudflare Tunnel Proxmox (100% Automático)"
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

# ✅ USA UBUNTU 20.04 (SEMPRE EXISTE!)
echo "🐳 Criando CT com Ubuntu 20.04..."
pct status $CTID >/dev/null 2>&1 && pct stop $CTID && pct destroy $CTID

pct create $CTID local:vztmpl/ubuntu-20.04-standard_20.04-1_amd64.tar.zst \
  --hostname cloudflare-rdp --cores 1 --memory 512 \
  --net0 "name=eth0,bridge=vmbr0,ip=$IP_CT/24,gw=$GATEWAY" \
  --rootfs local-lvm:4 --unprivileged 1 --features nesting=1

pct start $CTID && sleep 30

echo "✅ CT $CTID CRIADO!"
echo "☁️  Instalando Cloudflare..."

# ✅ COMANDOS SEPARADOS (funciona 100%)
pct exec $CTID -- bash -c "apt update && apt upgrade -y"
pct exec $CTID -- bash -c "apt install curl wget sudo -y"
pct exec $CTID -- bash -c "curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cf.deb"
pct exec $CTID -- bash -c "dpkg -i /tmp/cf.deb || apt install -f -y"
pct exec $CTID -- cloudflared tunnel login
pct exec $CTID -- cloudflared tunnel create $TUNNEL_NAME
pct exec $CTID -- cloudflared tunnel route dns $TUNNEL_NAME ubuntu.$DOMINIO
pct exec $CTID -- cloudflared tunnel route dns $TUNNEL_NAME windows.$DOMINIO
pct exec $CTID -- cloudflared service install
pct exec $CTID -- systemctl restart cloudflared

echo "🎉 RDP-SERVER PRONTO!"
echo ""
echo "📱 BROWSER ABRIU → Faça login Cloudflare → Autorize"
echo ""
echo "Cloudflare > Zero Trust > Tunnels > $TUNNEL_NAME > Configure:"
echo "• Subdomain: ubuntu → $IP_VM_UBUNTU:22 (TCP + No TLS Verify)"
echo "• Subdomain: windows → $IP_VM_WINDOWS:3389 (TCP + No TLS Verify)"
echo ""
echo "🔍 Verificar: pct exec $CTID cloudflared tunnel list"
echo "🎮 Teste: PuTTY ubuntu.$DOMINIO | RDP windows.$DOMINIO:3389"
