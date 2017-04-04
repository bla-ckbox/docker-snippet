#!/bin/bash

BACKUP_DIR='/opt/backup'
EXLUDE_FILE='/opt/webops/docker/backup/backup-exclude'

# Exclude infra container
EXCLUDE_CONTAINER="${EXCLUDE_CONTAINER} $(docker ps -qf 'name=/rancher-agent')"
EXCLUDE_CONTAINER="${EXCLUDE_CONTAINER} $(docker ps -qf 'label=io.rancher.scheduler.global' | tr '\n' ' ')"
EXCLUDE_CONTAINER="${EXCLUDE_CONTAINER} $(docker ps -qf 'label=io.rancher.container.agent_id' | tr '\n' ' ')"
EXCLUDE_CONTAINER="${EXCLUDE_CONTAINER} $(docker ps -qf 'label=io.rancher.container.name=dev2_gearmand_1')"
echo "Exclude: ${EXCLUDE_CONTAINER}"

cd ${BACKUP_DIR}
for CONTAINER_ID in $( docker ps -q -f "$1" ); do
  if [ $(echo ${EXCLUDE_CONTAINER} | grep -c ${CONTAINER_ID}) -eq 0 ] ; then
    unset VOLUMES NAME
    VOLUMES=$( docker inspect -f '{{ range .Mounts }}{{ if eq .Driver "local" }}{{ .Destination }}{{ end }}{{ end }}' ${CONTAINER_ID} | sed 's/[^ ]\+\/logs\?\/\?[^ ]* \?//' )
    NAME=$( docker inspect -f '{{.Name}}' ${CONTAINER_ID} )
    if [ $(find /opt/mysqldump -type f  -name "${NAME#/}-*.sql.gz" -mmin -240 | wc -l) -ne 0 ]; then
      echo "Backup ${NAME} [${CONTAINER_ID}]: Skipping (Databases already dumped)";
    elif [ -n "$VOLUMES" ] ; then
      echo "Backup ${NAME} [${CONTAINER_ID}]: $VOLUMES"
      if [ -f "${BACKUP_DIR}${NAME}.tgz" ] ; then rm -f "${BACKUP_DIR}${NAME}.tgz"; fi
      docker pause ${CONTAINER_ID} >> /dev/null
      docker run --name bkp_${CONTAINER_ID} --volumes-from ${CONTAINER_ID} -v ${BACKUP_DIR}:/backup -v ${EXLUDE_FILE}:/exclude.txt centos tar -P -czf /backup${NAME}.tgz -X /exclude.txt $VOLUMES
      docker unpause ${CONTAINER_ID} >> /dev/null
      docker rm bkp_${CONTAINER_ID}
    fi
  fi
done

docker rm bkp_${CONTAINER_ID}

find ${BACKUP_DIR} -type f -name '*.tgz' -mtime +3 -delete
