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
  ufw
msg_ok "Dependencies installed"

# ── 2. Aeroplane ──────────────────────────────────────────────────────────────
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
msg_ok "UFW enabled — open: 22, 80, 443, ${AEROPLANE_PORT}"

# ── Cleanup ───────────────────────────────────────────────────────────────────
msg_info "Cleaning up"
$STD apt-get autoremove -y
$STD apt-get autoclean -y
msg_ok "Cleanup complete"
