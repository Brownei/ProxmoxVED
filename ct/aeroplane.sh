#!/usr/bin/env bash
source <(curl -fsSL https://git.community-scripts.org/community-scripts/ProxmoxVE/raw/branch/main/misc/build.func)

# ── App metadata ──────────────────────────────────────────────────────────────
APP="Docker + Portainer + Aeroplane"
var_tags="docker;portainer;aeroplane"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

# ── Aeroplane settings (override via env before running) ─────────────────────
export AEROPLANE_REPO_BRANCH="${AEROPLANE_REPO_BRANCH:-main}"
export AEROPLANE_PORT="${AEROPLANE_PORT:-4310}"
export PORTAINER_PORT="${PORTAINER_PORT:-9000}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  msg_info "Updating Docker Engine"
  $STD apt-get update
  $STD apt-get upgrade -y
  msg_ok "Docker updated"

  msg_info "Updating Portainer CE"
  $STD docker pull portainer/portainer-ce:latest
  $STD docker stop portainer
  $STD docker rm portainer
  $STD docker run -d \
    --name portainer \
    --restart always \
    -p "${PORTAINER_PORT}:9000" \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  msg_ok "Portainer CE updated"

  msg_info "Updating Aeroplane"
  $STD curl -fsSL https://get.aeroplane.run | \
    AEROPLANE_REPO_BRANCH="${AEROPLANE_REPO_BRANCH}" \
    AEROPLANE_PORT="${AEROPLANE_PORT}" \
    sh
  msg_ok "Aeroplane updated"

  msg_ok "Update Completed Successfully"
}

start
build_container
description

msg_info "Setting up LXC configuration for Docker"
cat >> "/etc/pve/lxc/${CTID}.conf" <<EOF

# Required for Docker inside LXC
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.mount.auto: proc:rw sys:rw
EOF
msg_ok "LXC patched for Docker"

msg_info "Running install script inside container"
lxc-attach -n "$CTID" -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/Brownei/ProxmoxVED/main/install/aeroplane-install.sh)" \
  -- \
  "$AEROPLANE_REPO_BRANCH" \
  "$AEROPLANE_PORT" \
  "$PORTAINER_PORT"
msg_ok "Install script completed"

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} is ready to use!${CL}"
echo -e "${INFO}${YW} Portainer UI:  ${CL}${BL}http://$(pct exec $CTID -- hostname -I | awk '{print $1}'):${PORTAINER_PORT}${CL}"
echo -e "${INFO}${YW} Portainer TLS: ${CL}${BL}https://$(pct exec $CTID -- hostname -I | awk '{print $1}'):9443${CL}"
echo -e "${INFO}${YW} Aeroplane local:${CL}${BL}http://$(pct exec $CTID -- hostname -I | awk '{print $1}'):${AEROPLANE_PORT}${CL}"
echo -e "${INFO}${YW} UFW rules:     ${CL}22, 80, 443, ${AEROPLANE_PORT}, 9443 allowed${CL}\n"
