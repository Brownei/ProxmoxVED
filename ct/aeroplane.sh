#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.docker.com/ | https://www.portainer.io/ | https://www.aeroplane.run/

APP="Aeroplane"
var_tags="${var_tags:-aeroplane}"
var_cpu="${var_cpu:-3}"
var_ram="${var_ram:-3024}"
var_disk="${var_disk:-40}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"   # Must be privileged for Docker
var_hostname="${var_hostname:-aeroplane}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

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
