#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

DOLPHINSCHEDULER_BIN=${DOLPHINSCHEDULER_HOME}/bin
DOLPHINSCHEDULER_SCRIPT=${DOLPHINSCHEDULER_HOME}/script
DOLPHINSCHEDULER_LOGS=${DOLPHINSCHEDULER_HOME}/logs

# start postgresql
initPostgreSQL() {
    echo "checking postgresql"
    if [ -n "$(ifconfig | grep ${POSTGRESQL_HOST})" ]; then
        echo "start postgresql service"
        rc-service postgresql restart

        # role if not exists, create
        flag=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${POSTGRESQL_USERNAME}'")
        if [ -z "${flag}" ]; then
            echo "create user"
            sudo -u postgres psql -tAc "create user ${POSTGRESQL_USERNAME} with password '${POSTGRESQL_PASSWORD}'"
        fi

        # database if not exists, create
        flag=$(sudo -u postgres psql -tAc "select 1 from pg_database where datname='dolphinscheduler'")
        if [ -z "${flag}" ]; then
            echo "init db"
            sudo -u postgres psql -tAc "create database dolphinscheduler owner ${POSTGRESQL_USERNAME}"
        fi

        # grant
        sudo -u postgres psql -tAc "grant all privileges on database dolphinscheduler to ${POSTGRESQL_USERNAME}"
    fi

    echo "connect postgresql service"
    v=$(sudo -u postgres PGPASSWORD=${POSTGRESQL_PASSWORD} psql -h ${POSTGRESQL_HOST} -U ${POSTGRESQL_USERNAME} -d dolphinscheduler -tAc "select 1")
    if [ "$(echo '${v}' | grep 'FATAL' | wc -l)" -eq 1 ]; then
        echo "Can't connect to database...${v}"
        exit 1
    fi

    echo "import sql data"
    ${DOLPHINSCHEDULER_SCRIPT}/create-dolphinscheduler.sh
}

# start zk
initZK() {
    echo -e "checking zookeeper"
    if [[ "${ZOOKEEPER_QUORUM}" = "127.0.0.1:2181" || "${ZOOKEEPER_QUORUM}" = "localhost:2181" ]]; then
        echo "start local zookeeper"
        /opt/zookeeper/bin/zkServer.sh restart
    else
        echo "connect remote zookeeper"
        echo "${ZOOKEEPER_QUORUM}" | awk -F ',' 'BEGIN{ i=1 }{ while( i <= NF ){ print $i; i++ } }' | while read line; do
            while ! nc -z ${line%:*} ${line#*:}; do
                counter=$((counter+1))
                if [ $counter == 30 ]; then
                    log "Error: Couldn't connect to zookeeper."
                    exit 1
                fi
                log "Trying to connect to zookeeper at ${line}. Attempt $counter."
                sleep 5
            done
        done
    fi
}

# start nginx
initNginx() {
    echo "start nginx"
    nginx &
}

# start master-server
initMasterServer() {
    echo "start master-server"
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh stop master-server
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh start master-server
}

# start worker-server
initWorkerServer() {
    echo "start worker-server"
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh stop worker-server
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh start worker-server
}

# start api-server
initApiServer() {
    echo "start api-server"
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh stop api-server
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh start api-server
}

# start logger-server
initLoggerServer() {
    echo "start logger-server"
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh stop logger-server
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh start logger-server
}

# start alert-server
initAlertServer() {
    echo "start alert-server"
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh stop alert-server
    ${DOLPHINSCHEDULER_BIN}/dolphinscheduler-daemon.sh start alert-server
}

# print usage
printUsage() {
    echo -e "Dolphin Scheduler is a distributed and easy-to-expand visual DAG workflow scheduling system,"
    echo -e "dedicated to solving the complex dependencies in data processing, making the scheduling system out of the box for data processing.\n"
    echo -e "Usage: [ all | master-server | worker-server | api-server | alert-server | frontend ]\n"
    printf "%-13s:  %s\n" "all"           "Run master-server, worker-server, api-server, alert-server and frontend."
    printf "%-13s:  %s\n" "master-server" "MasterServer is mainly responsible for DAG task split, task submission monitoring."
    printf "%-13s:  %s\n" "worker-server" "WorkerServer is mainly responsible for task execution and providing log services.."
    printf "%-13s:  %s\n" "api-server"    "ApiServer is mainly responsible for processing requests from the front-end UI layer."
    printf "%-13s:  %s\n" "alert-server"  "AlertServer mainly include Alarms."
    printf "%-13s:  %s\n" "frontend"      "Frontend mainly provides various visual operation interfaces of the system."
}

# init config file
source /root/startup-init-conf.sh

LOGFILE=/var/log/nginx/access.log
case "$1" in
    (all)
        initZK
        initPostgreSQL
        initMasterServer
        initWorkerServer
        initApiServer
        initAlertServer
        initLoggerServer
        initNginx
        LOGFILE=/var/log/nginx/access.log
    ;;
    (master-server)
        initZK
        initPostgreSQL
        initMasterServer
        LOGFILE=${DOLPHINSCHEDULER_LOGS}/dolphinscheduler-master.log
    ;;
    (worker-server)
        initZK
        initPostgreSQL
        initWorkerServer
        initLoggerServer
        LOGFILE=${DOLPHINSCHEDULER_LOGS}/dolphinscheduler-worker.log
    ;;
    (api-server)
        initPostgreSQL
        initApiServer
        LOGFILE=${DOLPHINSCHEDULER_LOGS}/dolphinscheduler-api-server.log
    ;;
    (alert-server)
        initPostgreSQL
        initAlertServer
        LOGFILE=${DOLPHINSCHEDULER_LOGS}/dolphinscheduler-alert.log
    ;;
    (frontend)
        initNginx
        LOGFILE=/var/log/nginx/access.log
    ;;
    (help)
        printUsage
        exit 1
    ;;
    (*)
        printUsage
        exit 1
    ;;
esac

exec tee ${LOGFILE}