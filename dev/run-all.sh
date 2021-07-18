#!/usr/bin/env bash

SELF=$(cd $(dirname $0) && pwd)
cd $SELF
cd ..

cd /tmp

function docker_exec {
  name=$1
  command=$2
  #test -t 1 && USE_TTY="t"
  docker exec -i${USE_TTY} ${name} bash -c "${command}" /dev/null 2>&1
}

function check_ready {
    recCode="1"
    counter=0
    name=$1
    command=$2
    while [[ $counter -lt 60 ]] ; do
      docker_exec "${1}" "${command}"
      recCode="$?"
      if [[ "$recCode" == "0" ]]; then
          echo "check success. try ${counter} times."
          break
      fi
      sleep 1
      echo "try ${counter} times."
      let "counter+=1"
    done
    echo $recCode
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

say() {
    printf 'mlsql-docker fail \n %s\n' "$1"
}

err() {
    say "$1" >&2
    exit 1
}

need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

need_ok() {
    if [[ $? -ne 0 ]]; then err "$1"; fi
}

assert_nz() {
    if [[ -z "$1" ]]; then err "assert_nz $2"; fi
}


ensure() {
    "$@"
    need_ok "command failed: $*"
}

ignore() {
    "$@"
}

check_port() {
if lsof -Pi :${1} -sTCP:LISTEN -t >/dev/null ; then
    return 1
else
    return 0
fi
}

need_cmd docker
need_cmd wget

# check command ready

echo "----clean all mlsql related containers-----"

ids=$(docker ps --all |grep mlsql|awk '{print $1}')
for v in $ids
do
echo $v
docker stop $v
docker rm $v
done

ensure check_port 3306
ensure check_port 9002
ensure check_port 9003

VERSION=1.6.0-SNAPSHOT

echo "------create mlsql-network-----"
docker network rm  mlsql-network
docker network create mlsql-network



echo "start mysql"

docker run --name mlsql-db -p 3306:3306 \
--network mlsql-network \
-e MYSQL_ROOT_PASSWORD=mlsql \
-d techmlsql/mlsql-db:1.6.0-SNAPSHOT


#EXEC_MLSQL_PREFIX="exec mysql -uroot -pmlsql --protocol=tcp "
#
#check_ready mlsql-console-mysql "${EXEC_MLSQL_PREFIX} -e 'SHOW CHARACTER SET'"
#
#if [[ "$?" != "0" ]];then
#   echo "cannot start mysql in docker"
#   exit 1
#fi
#
#echo "------create db mlsql cluster ------"
#
#docker_exec mlsql-console-mysql "${EXEC_MLSQL_PREFIX} -e 'create database mlsql_cluster'"
#docker_id=$(docker inspect -f   '{{.Id}}' mlsql-console-mysql)
#rm -rf cluster-db.sql
#wget download.mlsql.tech/scripts/cluster-db.sql .
#docker cp cluster-db.sql ${docker_id}:/tmp
#docker_exec mlsql-console-mysql "${EXEC_MLSQL_PREFIX} mlsql_cluster < /tmp/cluster-db.sql"
#
#
#echo "------create db mlsql_console ------"
#docker_exec mlsql-console-mysql "${EXEC_MLSQL_PREFIX} -e 'create database mlsql_console'"
#
##导入数据
#docker_id=$(docker inspect -f   '{{.Id}}' mlsql-console-mysql)
#rm -rf  console-db.sql
#wget download.mlsql.tech/scripts/console-db.sql .
#docker cp console-db.sql ${docker_id}:/tmp
#docker_exec mlsql-console-mysql "${EXEC_MLSQL_PREFIX} mlsql_console < /tmp/console-db.sql"


echo "------start mlsql engine ------"

docker run --name mlsql-server -d \
--network mlsql-network \
-p 9003:9003 \
techmlsql/mlsql:latest

echo "------sleep 10 senconds to make sure mysql is ready"
sleep 10

echo "------start mlsql console ------"
docker run --name mlsql-console \
--network mlsql-network \
-p 9002:9002 \
-e MLSQL_ENGINE_URL=http://mlsql-server:9003 \
-e MY_URL=http://mlsql-console:9002 \
-e USER_HOME=/tmp/users \
-e MYSQL_HOST=mlsql-db \
-d \
techmlsql/mlsql-console:1.6.0-SNAPSHOT







