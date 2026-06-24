#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Runs INSIDE the LXC — called automatically by build.func
# build.func injects $FUNCTIONS_FILE_PATH into the container environment

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

AEROPLANE_REPO_BRANCH="${AEROPLANE_REPO_BRANCH:-main}"
AEROPLANE_PORT="${AEROPLANE_PORT:-4310}"
PORTAINER_PORT="${PORTAINER_PORT:-9000}"

# ── 1. Dependencies ───────────────────────────────────────────────────────────
msg_info "Installing dependencies"
$STD apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  ufw
msg_ok "Dependencies installed"

# ── 2. Docker CE ──────────────────────────────────────────────────────────────
msg_info "Installing Docker CE"
$STD sh <(curl -fsSL https://get.docker.com)
$STD systemctl enable --now docker
msg_ok "Docker CE installed"

# Block here until Docker socket is live — Portainer & Aeroplane need it running
msg_info "Waiting for Docker daemon"
WAIT=0
until docker info &>/dev/null; do
  sleep 1
  WAIT=$((WAIT + 1))
  if [[ $WAIT -ge 30 ]]; then
    msg_error "Docker daemon did not become ready within 30s"
    exit 1
  fi
done
msg_ok "Docker daemon is ready"

# ── 3. Portainer CE ───────────────────────────────────────────────────────────
msg_info "Deploying Portainer CE"
$STD docker volume create portainer_data
$STD docker run -d \
  --name portainer \
  --restart always \
  -p "${PORTAINER_PORT}:9000" \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

cat > /etc/systemd/system/portainer-watchdog.service << UNIT
[Unit]
Description=Ensure Portainer is running after boot
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/docker start portainer
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
$STD systemctl enable portainer-watchdog.service
msg_ok "Portainer CE deployed on port ${PORTAINER_PORT}"

# ── 4. Aeroplane ──────────────────────────────────────────────────────────────
msg_info "Installing Aeroplane"
curl -fsSL https://get.aeroplane.run | \
  AEROPLANE_REPO_BRANCH="${AEROPLANE_REPO_BRANCH}" \
  AEROPLANE_PORT="${AEROPLANE_PORT}" \
  sh
msg_ok "Aeroplane installed on port ${AEROPLANE_PORT}"

# ── 5. UFW firewall ───────────────────────────────────────────────────────────
msg_info "Configuring UFW firewall"
$STD ufw default deny incoming
$STD ufw default allow outgoing
$STD ufw allow 22/tcp
$STD ufw allow 80/tcp
$STD ufw allow 443/tcp
$STD ufw allow "${AEROPLANE_PORT}/tcp"
$STD ufw allow 9443/tcp
echo "y" | $STD ufw enable
msg_ok "UFW enabled — open: 22, 80, 443, ${AEROPLANE_PORT}, 9443"

# ── Cleanup ───────────────────────────────────────────────────────────────────
msg_info "Cleaning up"
$STD apt-get autoremove -y
$STD apt-get autoclean -y
msg_ok "Cleanup complete"
