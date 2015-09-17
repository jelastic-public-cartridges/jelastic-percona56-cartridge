#!/bin/bash

# Copyright 2015 Jelastic, Inc.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source /etc/jelastic/environment 

LOG_FILE=/var/log/msqlresetpas.log;
MYSQLD_SAFE=$(which mysqld_safe)
MYSQL=$(which mysql);
CHKCONFIG=$(which chkconfig);
SERVICE_CMD=$(which service)
SERVICE_NAME="cartridge"
[ -f /opt/repo/jelastic/scripts/firewall.sh ] && {
    /bin/bash /opt/repo/jelastic/scripts/firewall.sh >/dev/null 2>/dev/null
    service iptables save >/dev/null 2>/dev/null
}

function _setPassword() {

                while [ "$1" != "" ]; 
                do
                  case $1 in
                    -u )       shift
                      local user=$1
                      ;;
                    -p )       shift
                      local password=$1
                      ;;
                  esac
                  shift
                done

                local tries=200
                local tries2=200
                local pid=${OPENSHIFT_PERCONADB_DIR}/pid/perconadb.pid

                local db='mysql'
                echo $(date)  >> $LOG_FILE
                echo "Using service $SERVICE_NAME"  >> $LOG_FILE
                $SERVICE_CMD $SERVICE_NAME stop >> $LOG_FILE 2>&1
               [ -f "/var/lib/mysql/auto.cnf" ] && rm "/var/lib/mysql/auto.cnf";

                while [ "$tries" -gt 0 ]
                do
                        if ! ps aux | grep -v -E 'grep|mysql-systemd' | grep -q  mysql ;
                        then
                                break;
                        fi
                        sleep 1
                        tries=$(($tries-1))
                        $SERVICE_CMD ${SERVICE_NAME} stop >> $LOG_FILE 2>&1
                done

                echo "Mysql stopped" >> $LOG_FILE

                if ps aux | grep -v grep | grep -q  mysqld ;  then /usr/bin/killall mysqld 1>>$LOG_FILE 2>&1; /usr/bin/killall mysqld_safe 1>>$LOG_FILE 2>&1; fi
                sed -i '/\[mysqld\]/askip-grant-tables' $J_OPENSHIFT_APPHOME_DIR/conf/my.cnf
                $SERVICE_CMD ${SERVICE_NAME} start >> $LOG_FILE 2>&1
                sleep 5;
        	$MYSQL $db -h 127.0.0.1 --execute="UPDATE user SET Password=PASSWORD('${J_OPENSHIFT_APP_ADM_PASSWORD}') WHERE user='${Admin_App_User}';"
                $MYSQL $db -h 127.0.0.1 --execute="DELETE FROM user WHERE user = '';"
                $MYSQL $db -h 127.0.0.1 --execute="FLUSH PRIVILEGES;"

                sleep 2
                $SERVICE_CMD ${SERVICE_NAME} stop >> $LOG_FILE 2>&1
                tries=200
                echo "Stopping Mysql after set password " >> $LOG_FILE
                while [ "$tries" -gt 0 ]
                do
                        if ! ps aux | grep -v -E 'grep|mysql-systemd' | grep -q mysql ;
                        then
                                break;
                        fi
                        sleep 1
                        tries=$(($tries-1))
                        $SERVICE_CMD ${SERVICE_NAME} stop >> $LOG_FILE 2>&1
                done
                sed -i  '/skip-grant-tables/d' $J_OPENSHIFT_APPHOME_DIR/conf/my.cnf
                $SERVICE_CMD ${SERVIC_NAME} start  >>$LOG_FILE 2>&1
                if ! ps aux | grep -v -E 'grep|mysql-systemd' | grep -q  mysql ;
                then
                        sleep 2
                        $SERVICE_CMD ${SERVICE_NAME} start >>$LOG_FILE 2>&1

                fi
                echo "Password updated" >> $LOG_FILE
                $CHKCONFIG --level 3 ${SERVICE_NAME} on >>$LOG_FILE 2>&1
}
