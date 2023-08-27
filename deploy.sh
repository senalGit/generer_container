#!/usr/bin/bash
#Author : Xavier Xavki
set -eo pipefail

# Variables ###################################################
export ANSIBLE_DIR="projet_ansible"
export REPERTOIRE_VARS=("roles" "host_vars" "group_vars" "playbooks")
export FILE_GROUPS_VARS=("all" "db" "web")
export hosts=()
export listroles=("db_role" "app_role" "ssh_keygen_role" "users_role" "nginx_role")

# Functions ###################################################

help() {
  echo "
Usage: $0 
-c <number> : create container and add the number of containers
-i : information (ip and name)_role
-s : start all containers created by this script
-t : same to stop all containers
-d : same for drop all containers
-a : create an inventory for ansible with all ips
  "
}

createContainers() {
  CONTAINER_NUMBER=$1
  CONTAINER_HOME=/home/${USER}
  CONTAINER_CMD="sudo podman exec "

  # Calcul du id à utiliser
  id_already=$(sudo podman ps -a --format '{{ .Names}}' | awk -v user="${USER}" '$1 ~ "^"user {count++} END {print count}')
  id_min=$((id_already + 1))
  id_max=$((id_already + ${CONTAINER_NUMBER}))

  # Création des conteneurs en boucle
  for i in $(seq $id_min $id_max); do
    sudo podman run -d --systemd=true --publish-all=true -v /srv/data:/srv/data --name ${USER}-debian-$i -h ${USER}-debian-$i docker.io/priximmo/buster-systemd-ssh

    ${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "useradd -m -p kirikou ${USER}"
    ${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "mkdir -m 0700 ${CONTAINER_HOME}/.ssh && chown ${USER}:${USER} ${CONTAINER_HOME}/.ssh"
    sudo podman cp ${HOME}/.ssh/id_rsa.pub ${USER}-debian-$i:${CONTAINER_HOME}/.ssh/authorized_keys
    ${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "chmod 600 ${CONTAINER_HOME}/.ssh/authorized_keys && chown ${USER}:${USER} ${CONTAINER_HOME}/.ssh/authorized_keys"
    ${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "echo '${USER}   ALL=(ALL) NOPASSWD: ALL'>>/etc/sudoers"
    ${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "service ssh start"

    ${CONTAINER_CMD} ${USER}-debian-$i /bin/bash -c "sed -i 's/deb http:\/\/deb.debian.org\/debian stretch-backports main/#deb http:\/\/deb.debian.org\/debian stretch-backports main/' /etc/apt/sources.list
"

  done

  infosContainers

  exit 0
}

infosContainers() {
  echo -e "Informations des conteneurs :\n"
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"[ {{.Name}} ] -- Adresse : {{.NetworkSettings.IPAddress}}\" "$1)}'
  exit 0
}

dropContainers() {
  sudo podman ps -a --format {{.Names}} | awk -v user=${USER} '$1 ~ "^"user {print $1" - Suppresseion..."; system("sudo podman rm -f "$1)}'
  #infosContainers
}

startContainers() {
  sudo podman ps -a --format {{.Names}} | awk -v user=${USER} '$1 ~ "^"user {print $1" - Demarrage...";system("sudo podman start "$1)}'
  infosContainers
}

stopContainers() {
  sudo podman ps -a --format {{.Names}} | awk -v user=${USER} '$1 ~ "^"user {system(print $1" - Arrêt...";"sudo podman stop "$1)}'
  infosContainers
}

createAnsible() {

  mkdir -p ${ANSIBLE_DIR}
  echo -e "all:\n  vars:\n    ansible_python_interpreter: /usr/bin/python3\n  hosts:" | tee ${ANSIBLE_DIR}/00_inventory.yml
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"    {{.NetworkSettings.IPAddress}}:\" "$1)}' | tee -a ${ANSIBLE_DIR}/00_inventory.yml

  creer_repertoire_ansible
  echo -e "\nStructure du dossier Ansible :"
 # tree ${ANSIBLE_DIR}
}



creer_repertoire_ansible() {

  #local hosts=sudo podman ps -aq | awk '{system("sudo podman inspect -f \"{{.NetworkSettings.IPAddress}}\" "$1)}'

  for REPERTOIRE in ${REPERTOIRE_VARS[@]}; do
    local dir=${ANSIBLE_DIR}/${REPERTOIRE}
    mkdir -p ${dir}

    case "$REPERTOIRE" in
    group_vars)
      for file in ${FILE_GROUPS_VARS[@]}; do
        touch "${dir}/${file}.yml"
      done
      ;;
    host_vars)
      touch "${dir}/main.yml"
      for file in ${hosts[@]}; do
        touch "${dir}/${file}.yml"
      done
      ;;
    roles)
      for role in ${listroles[@]}; do

        local sub_dir_role="${dir}/${role}"

        if [ ! -d "${sub_dir_role}" ]; then
          ansible-galaxy init "${sub_dir_role}"
        fi
        
      done
      ;;

    *)
      echo default
      ;;
    esac
  done

}

if [ "$#" -eq 0 ]; then
  help
fi

while getopts ":c:ahitsd" options; do
  case "${options}" in
  a)
    createAnsible
    ;;
  c)
    createContainers ${OPTARG}
    ;;
  i)
    infosContainers
    ;;
  s)
    startContainers
    ;;
  t)
    stopContainers
    ;;
  d)
    dropContainers
    ;;
  h)
    help
    exit 1
    ;;
  *)
    help
    exit 1
    ;;
  esac
done
