#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.docker.com/ | https://www.portainer.io/ | https://www.aeroplane.run/

APP="Docker + Portainer + Aeroplane"
var_tags="${var_tags:-docker;portainer;aeroplane}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-0}"   # Must be privileged for Docker
var_nesting="${var_nesting:-1}"             # Required for Docker inside LXC
var_keyctl="${var_keyctl:-1}"               # Required for Docker inside LXC

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  msg_info "Updating base system"
  $STD apt-get update
  $STD apt-get upgrade -y
  msg_ok "Base system updated"

  msg_info "Updating Docker Engine"
  $STD apt-get install --only-upgrade -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  msg_ok "Docker Engine updated"

  msg_info "Updating Portainer CE"
  $STD docker pull portainer/portainer-ce:latest
  $STD docker stop portainer || true
  $STD docker rm portainer || true
  $STD docker run -d \
    --name portainer \
    --restart always \
    -p 9000:9000 \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  msg_ok "Portainer CE updated"

  msg_info "Updating Aeroplane"
  curl -fsSL https://get.aeroplane.run | \
    AEROPLANE_REPO_BRANCH="${AEROPLANE_REPO_BRANCH:-main}" \
    AEROPLANE_PORT="${AEROPLANE_PORT:-4310}" \
    sh
  msg_ok "Aeroplane updated"

  msg_ok "Update Completed Successfully"
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup is complete.${CL}"
echo -e "${INFO}${YW} Portainer:  ${CL}${BL}http://${IP}:9000${CL}"
echo -e "${INFO}${YW} Aeroplane:  ${CL}${BL}http://${IP}:${AEROPLANE_PORT:-4310}${CL}"
