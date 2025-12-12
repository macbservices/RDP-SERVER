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

# Perguntas mínimas (igual TVBOX)
read -p "☁️  Nome do Túnel Cloudflare: " TUNNEL_NAME
read -p "🌐 Seu domínio (ex: grythprogress.com.br): " DOMINIO
read -p "📋 TOKEN Zero Trust (copie do painel): " TOKEN_CF

# Detecta VMs (últimos CTs/VMs)
VM_UBUNTU=$(pct list | grep ubuntu | tail -1 | awk '{print $1}' | xargs -I {} pct exec {} -- hostname || echo "192.168.1.10")
VM_WINDOWS=$(qm list | grep win | tail -1 | awk '{print $1}' | xargs -I {} qm config {} | grep ipconfig | head -1 || echo "192.168.1.20")

IP_VM_UBUNTU="${IP_BASE}.10"
IP_VM_WINDOWS="${IP_BASE}.20"

echo ""
echo "🔍 Configuração detectada:"
echo "   Túnel: $TUNNEL_NAME"
echo "   CT IP: $IP_CT"
echo "   Ubuntu SSH: ubuntu.$DOMINIO → $IP_VM_UBUNTU:22"
echo "   Windows RDP: windows.$DOMINIO → $IP_VM_WINDOWS:3389"
echo ""
read -p "✅ Prosseguir? (s/N): " CONFIRM
[[ $CONFIRM =~ ^[Ss] ]] || exit 0

# Limpa CT se existir
pct status $CTID >/dev/null 2>&1 && pct stop $CTID && pct destroy $CTID

# Cria CT Ubuntu
echo "🐳 Criando CT $CTID..."
pct create $CTID local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst \
  --hostname cloudflare-rdp --cores 1 --memory 512 \
  --net0 "name=eth0,bridge=vmbr0,ip=$IP_CT/24,gw=$GATEWAY" \
  --rootfs local-lvm:4 --unprivileged 1 --features nesting=1

pct start $CTID && sleep 10

# Instala Cloudflare Tunnel
echo "☁️  Instalando cloudflared..."
pct exec $CTID bash -c "
apt update -y && apt upgrade -y
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
dpkg -i cloudflared.deb
cloudflared service install '$TOKEN_CF'
systemctl restart cloudflared && systemctl enable cloudflared
cloudflared tunnel route dns $TUNNEL_NAME ubuntu.$DOMINIO
cloudflared tunnel route dns $TUNNEL_NAME windows.$DOMINIO
"

echo "✅ RDP-SERVER PRONTO!"
echo ""
echo "🎮 Cloudflare Automático:"
echo "1. Zero Trust > Tunnels > $TUNNEL_NAME > Configure"
echo "2. Public Hostname → ADICIONE:"
echo "   • ubuntu.$DOMINIO → $IP_VM_UBUNTU:22 (TCP + No TLS Verify)"
echo "   • windows.$DOMINIO → $IP_VM_WINDOWS:3389 (TCP + No TLS Verify)"
echo ""
echo "🔍 Status: pct exec $CTID cloudflared tunnel list"
echo "🎮 Teste: PuTTY ubuntu.$DOMINIO | RDP windows.$DOMINIO:3389"
