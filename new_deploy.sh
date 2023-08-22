#!/usr/bin/bash

set -eo pipefail

# Variables ###################################################
export ANSIBLE_DIR="projet_ansible"
export REPERTOIRE_VARS=("all" "host_vars" "group_vars")
export FICHIERS_VARS=("all_vars.yml" "host_vars.yml" "group_vars.yml")

# Functions ###################################################

help(){
  echo "
Usage: $0 
-c <number> : create container and add the number of containers
-i : information (ip and name)
-s : start all containers created by this script
-t : same to stop all containers
-d : same for drop all containers
-a : create an inventory for ansible with all ips
  "
}

createContainers(){
  CONTAINER_NUMBER=$1
  CONTAINER_HOME=/home/${USER}
  CONTAINER_CMD="sudo podman exec "

	# Calcul du id à utiliser
  id_already=`sudo podman ps -a --format '{{ .Names}}' | awk -v user="${USER}" '$1 ~ "^"user {count++} END {print count}'`
  id_min=$((id_already + 1))
  id_max=$((id_already + ${CONTAINER_NUMBER}))
  
	# Création des conteneurs en boucle
	for i in $(seq $id_min $id_max);do
		sudo podman run -d --systemd=true --publish-all=true -v /srv/data:/srv/data --name ${USER}-debian-$i -h ${USER}-debian-$i docker.io/priximmo/buster-systemd-ssh
		${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "useradd -m -p kirikou ${USER}"
		${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "mkdir -m 0700 ${CONTAINER_HOME}/.ssh && chown ${USER}:${USER} ${CONTAINER_HOME}/.ssh"
		sudo podman cp ${HOME}/.ssh/id_rsa.pub ${USER}-debian-$i:${CONTAINER_HOME}/.ssh/authorized_keys
		${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "chmod 600 ${CONTAINER_HOME}/.ssh/authorized_keys && chown ${USER}:${USER} ${CONTAINER_HOME}/.ssh/authorized_keys"
		${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "echo '${USER}   ALL=(ALL) NOPASSWD: ALL'>>/etc/sudoers"
		${CONTAINER_CMD} ${USER}-debian-$i /bin/sh -c "service ssh start"
	done

	infosContainers

  exit 0
}

infosContainers(){
	echo ""
	echo "Informations des conteneurs : "
	echo ""
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"{{.Name}} -- IP: {{.NetworkSettings.IPAddress}}\" "$1)}'
	echo ""
  exit 0
}

dropContainers(){
  sudo podman ps -a --format {{.Names}} | awk -v user=${USER} '$1 ~ "^"user {print $1" - Suppresseion...";system("sudo podman rm -f "$1)}'
  infosContainers
}

startContainers(){
  sudo podman ps -a --format {{.Names}} | awk -v user=${USER} '$1 ~ "^"user {print $1" - Demarrage...";system("sudo podman start "$1)}'
  infosContainers
}

stopContainers(){
  sudo podman ps -a --format {{.Names}} | awk -v user=${USER} '$1 ~ "^"user {system(print $1" - Arrêt...";"sudo podman stop "$1)}'
  infosContainers
}

createAnsible(){

  mkdir -p ${ANSIBLE_DIR}
  echo -e "all:\n  vars:\n    ansible_python_interpreter: /usr/bin/python3\n  hosts:" | tee ${ANSIBLE_DIR}/00_inventory.yml
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"    {{.NetworkSettings.IPAddress}}:\" "$1)}' | tee -a ${ANSIBLE_DIR}/00_inventory.yml

creer_repertoire_ansible
  echo -e "\nStructure du dossier Ansible :"
  tree ${ANSIBLE_DIR}
}

creer_repertoire_ansible(){
  for REPERTOIRE in ${REPERTOIRE_VARS[@]}
  do
    local dir=${ANSIBLE_DIR}/${REPERTOIRE}
    mkdir -p ${dir}
    touch "${dir}/vars_${REPERTOIRE}.yml"
  done
  
}


if [ "$#" -eq  0 ];then
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
