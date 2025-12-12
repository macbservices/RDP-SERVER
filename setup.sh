#!/bin/bash
# Script para Proxmox: Cria LXC Ubuntu + Cloudflare Tunnel para VMs
CTID=999  # ID do novo CT (ajuste se ocupado)
IP_CT="192.168.100.100/24"  # IP estático do CT (ajuste à sua rede)
GATEWAY="192.168.100.1"     # Gateway da rede
DNS="1.1.1.1"
TOKEN_CF="SEU_TOKEN_AQUI"  # Cole o token do Zero Trust Tunnel aqui
SUB_UBUNTU="ubuntu"        # ubuntu.grythprogress.com.br
IP_VM_UBUNTU="192.168.100.10" # IP da VM Ubuntu
SUB_WINDOWS="windows"      # windows.grythprogress.com.br
IP_VM_WINDOWS="192.168.100.20" # IP da VM Windows

echo "Criando LXC Ubuntu $CTID..."
pct create $CTID local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst \
  --hostname cloudflare-ct --cores 1 --memory 512 --swap 512 --net0 name=eth0,bridge=vmbr0,ip=$IP_CT,gw=$GATEWAY \
  --rootfs local-lvm:4 --unprivileged 1 --features nesting=1
pct start $CTID
pct exec $CTID -- bash -c "apt update && apt upgrade -y && apt install curl wget -y"
pct exec $CTID -- bash -c "curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb && dpkg -i /tmp/cloudflared.deb"
pct exec $CTID -- bash -c "cloudflared service install $TOKEN_CF && systemctl restart cloudflared && systemctl enable cloudflared"

echo "Configurando túneis via API (edite config.yml manualmente ou use API CF)"
pct exec $CTID -- bash -c "cloudflared tunnel route dns proxmox-tunnel $SUB_UBUNTU.grythprogress.com.br"
# Nota: Para túneis SSH/RDP, configure manual no painel CF após rodar script (Public Hostnames: TCP://$IP_VM_UBUNTU:22 e TCP://$IP_VM_WINDOWS:3389 com No TLS Verify)

echo "CT pronto! Acesse console CT $CTID e verifique: cloudflared tunnel list"
