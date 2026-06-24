#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Runs INSIDE the LXC container — called automatically by build.func

source /dev/stdin <<< "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)"

AEROPLANE_REPO_BRANCH="${AEROPLANE_REPO_BRANCH:-main}"
AEROPLANE_PORT="${AEROPLANE_PORT:-4310}"
PORTAINER_PORT="${PORTAINER_PORT:-9000}"

# ── 1. Base dependencies ──────────────────────────────────────────────────────
msg_info "Installing base dependencies"
$STD apt-get update
$STD apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  ufw
msg_ok "Base dependencies installed"

# ── 2. Docker CE — must fully start before anything else runs ─────────────────
msg_info "Adding Docker apt repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  >/etc/apt/sources.list.d/docker.list
$STD apt-get update
msg_ok "Docker repository configured"

msg_info "Installing Docker CE"
$STD apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
msg_ok "Docker CE packages installed"

msg_info "Starting Docker daemon"
$STD systemctl enable docker
$STD systemctl start docker
# Block until the Docker socket accepts connections — Portainer and Aeroplane need this
WAIT=0
until docker info &>/dev/null; do
  sleep 1
  WAIT=$((WAIT + 1))
  if [[ $WAIT -ge 30 ]]; then
    msg_error "Docker daemon did not become ready within 30s"
    exit 1
  fi
done
msg_ok "Docker CE $(docker --version | awk '{print $3}' | tr -d ',') is running"

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

cat >/etc/systemd/system/portainer-watchdog.service <<UNIT
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
ufw default deny incoming
ufw default allow outgoing
$STD ufw allow 22/tcp
$STD ufw allow 80/tcp
$STD ufw allow 443/tcp
$STD ufw allow "${AEROPLANE_PORT}/tcp"
$STD ufw allow 9443/tcp
echo "y" | ufw enable
msg_ok "UFW enabled — open ports: 22, 80, 443, ${AEROPLANE_PORT}, 9443"

# ── Cleanup ───────────────────────────────────────────────────────────────────
msg_info "Cleaning up"
$STD apt-get autoremove -y
$STD apt-get autoclean -y
msg_ok "Cleanup complete"
