#!/bin/bash
clear
echo "🚀 RDP-SERVER: Cloudflare Tunnel Proxmox (Automático)"
echo "================================================================"

# Verifica Proxmox
command -v pct >/dev/null 2>&1 || { echo "❌ Execute no HOST Proxmox!"; exit 1; }

# Detecta rede automaticamente
IP_CT=$(ip -4 route get 1 | awk '{print $7}' | head -1)
IP_BASE=${IP_CT%.*}
GATEWAY=$(ip route | grep default | awk '{print $3}')
DNS="1.1.1.1"
CTID=999

# APENAS 2 perguntas (igual TVBOX)
read -p "☁️  Nome do Túnel Cloudflare: " TUNNEL_NAME
read -p "🌐 Seu domínio (ex: grythprogress.com.br): " DOMINIO

IP_VM_UBUNTU="${IP_BASE}.10"
IP_VM_WINDOWS="${IP_BASE}.20"

echo ""
echo "🔍 Configuração automática:"
echo "   Túnel: $TUNNEL_NAME"
echo "   CT IP: $IP_CT"
echo "   Ubuntu: ubuntu.$DOMINIO → $IP_VM_UBUNTU:22"
echo "   Windows: windows.$DOMINIO → $IP_VM_WINDOWS:3389"
echo ""
read -p "✅ Prosseguir? (s/N): " CONFIRM
[[ $CONFIRM =~ ^[Ss] ]] || exit 0

# Limpa CT anterior
pct status $CTID >/dev/null 2>&1 && pct stop $CTID && pct destroy $CTID

# Cria CT Ubuntu 24.04
echo "🐳 Criando CT $CTID..."
pct create $CTID local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst \
  --hostname cloudflare-rdp --cores 1 --memory 512 \
  --net0 "name=eth0,bridge=vmbr0,ip=$IP_CT/24,gw=$GATEWAY" \
  --rootfs local-lvm:4 --unprivileged 1 --features nesting=1

pct start $CTID && sleep 10

# Instala Cloudflare + AUTENTICAÇÃO AUTOMÁTICA (igual TVBOX)
echo "☁️  Instalando Cloudflare Tunnel (OAuth automático)..."
pct exec $CTID bash -c "
apt update -y && apt install curl wget sudo -y
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
dpkg -i /tmp/cloudflared.deb
cloudflared tunnel login  # ← ABRE BROWSER AUTOMÁTICO
cloudflared tunnel create $TUNNEL_NAME
cloudflared tunnel route dns $TUNNEL_NAME ubuntu.$DOMINIO
cloudflared tunnel route dns $TUNNEL_NAME windows.$DOMINIO
cloudflared tunnel run $TUNNEL_NAME &
echo 'cloudflared tunnel run $TUNNEL_NAME' | sudo tee /etc/systemd/system/cloudflared.service
systemctl daemon-reload && systemctl enable cloudflared
"

echo "✅ RDP-SERVER PRONTO 100% AUTOMÁTICO!"
echo ""
echo "🎮 No navegador que abriu:"
echo "1. Faça login Cloudflare"
echo "2. Autorize → Túnel criado!"
echo ""
echo "📋 Cloudflare Painel → Tunnels → $TUNNEL_NAME → Configure:"
echo "• ubuntu.$DOMINIO → $IP_VM_UBUNTU:22 (TCP + No TLS Verify)"
echo "• windows.$DOMINIO → $IP_VM_WINDOWS:3389 (TCP + No TLS Verify)"
echo ""
echo "🔍 Status: pct exec $CTID cloudflared tunnel list"
