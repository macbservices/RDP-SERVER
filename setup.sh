#!/bin/bash
clear
echo "🚀 RDP-SERVER: Cloudflare Tunnel Proxmox (Automático)"
echo "================================================================"

# Verifica Proxmox HOST
command -v pct >/dev/null 2>&1 && command -v qm >/dev/null 2>&1 || { echo "❌ HOST Proxmox Shell!"; exit 1; }

# Detecta rede
IP_CT=$(ip -4 route get 1 | awk '{print $7}' | head -1)
IP_BASE=${IP_CT%.*}
GATEWAY=$(ip route | grep default | awk '{print $3}')
CTID=999

# 2 perguntas SÓ
read -p "☁️  Nome do Túnel: " TUNNEL_NAME
read -p "🌐 Domínio BASE (ex: grythprogress.com.br): " DOMINIO_BASE

# Corrige domínio (remove subdomínios)
DOMINIO=${DOMINIO_BASE#*.}  # Pega só grythprogress.com.br
IP_VM_UBUNTU="${IP_BASE}.10"
IP_VM_WINDOWS="${IP_BASE}.20"

echo ""
echo "🔍 Configuração:"
echo "   Túnel: $TUNNEL_NAME"
echo "   CT: $IP_CT"
echo "   SSH: ubuntu.$DOMINIO → $IP_VM_UBUNTU:22"
echo "   RDP: windows.$DOMINIO → $IP_VM_WINDOWS:3389"
read -p "✅ OK? (s/N): " OK && [[ $OK =~ ^[Ss] ]] || exit

# Baixa template Ubuntu se não existir
pveam update && pveam download local ubuntu-22.04-standard_22.04-2_amd64.tar.zst

# Limpa CT anterior
pct status $CTID >/dev/null 2>&1 && pct stop $CTID && pct destroy $CTID

# Cria CT Ubuntu 22.04 (mais estável)
echo "🐳 Criando CT $CTID..."
pct create $CTID local:vztmpl/ubuntu-22.04-standard_22.04-2_amd64.tar.zst \
  --hostname cloudflare-rdp --cores 1 --memory 512 \
  --net0 "name=eth0,bridge=vmbr0,ip=$IP_CT/24,gw=$GATEWAY" \
  --rootfs local-lvm:4 --unprivileged 1 --features nesting=1

pct start $CTID && sleep 15

# Cloudflare OAuth AUTOMÁTICO
echo "☁️  Cloudflare Tunnel..."
pct exec $CTID -- bash -c "
apt update && apt install curl sudo -y
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cf.deb
dpkg -i /tmp/cf.deb || apt install -f -y
cloudflared tunnel login
cloudflared tunnel create $TUNNEL_NAME
cloudflared tunnel route dns $TUNNEL_NAME ubuntu.$DOMINIO
cloudflared tunnel route dns $TUNNEL_NAME windows.$DOMINIO
cloudflared service install
systemctl restart cloudflared
"

echo "✅ RDP-SERVER PRONTO!"
echo ""
echo "🎮 BROWSER ABRIU → Login Cloudflare → Autorize"
echo ""
echo "📋 Cloudflare > Tunnels > $TUNNEL_NAME > Public Hostname:"
echo "• ubuntu.$DOMINIO → $IP_VM_UBUNTU:22 (TCP + No TLS Verify)"
echo "• windows.$DOMINIO → $IP_VM_WINDOWS:3389 (TCP + No TLS Verify)"
echo ""
echo "🔍 pct exec $CTID cloudflared tunnel list"
