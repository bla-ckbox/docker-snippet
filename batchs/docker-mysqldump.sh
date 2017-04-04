#!/bin/bash

MYSQLDUMPDIR='/opt/mysqldump'
MYSQLBINDIR='/usr/local/mysql/bin'
IMAGEFILTER='registry:5000/pvcp/mariadb'


# Get Mariadb Container
for c in $( docker ps -q ) ; do
  # Use docker inspect to get image name no available if image is not present
  for cni in $( docker inspect --format='{{.Id}} {{.Config.Image}}' ${c} | awk "\$2~\"${IMAGEFILTER}\" { print \$1 }" ); do
    cn=$( docker inspect -f '{{ index .Config.Labels "io.rancher.container.name" }}' ${cni} )
    if [ -z "${cn}" ] ; then cn="${cni:0:12}"; fi
    echo ${cn}
    # Get DB list on Container
    for db in $(docker exec ${cni} ${MYSQLBINDIR}/mysql -NBe 'show databases;' | sed 's/\r//g'| grep -vE '(information_schema|performance_schema)' ); do
      echo "# Backup ${cn}-${db}"
      dumpfile="${MYSQLDUMPDIR}/${cn}-${db}.sql.gz"
      if [ -f "${dumpfile}" ] ; then rm -f ${dumpfile} 2>/dev/null; fi
      docker exec ${cni} ${MYSQLBINDIR}/mysqldump ${db} | /bin/gzip > ${dumpfile}
    done
  done
done
