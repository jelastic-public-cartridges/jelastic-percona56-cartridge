#!/bin/bash 
source /etc/jelastic/environment
SED=$(which sed);

CHKCONFIG=$(which chkconfig)
MySQLConfigPath="$J_OPENSHIFT_APPHOME_DIR/conf/my.cnf"
RamMin=200
LOG_FILE="/var/log/autoconfig.log"
VERBOSE=0
 
log() {
 if [ $VERBOSE -gt 0 ]; then
     echo -n `date +%D.%k:%M:%S.%N` >> ${LOG_FILE}
     echo ": $@" >> ${LOG_FILE}
 fi
 if [ $VERBOSE -gt 1 ]; then
     echo -n `date +%D.%k:%M:%S.%N`
     echo ": $@"
 fi
}

backupconfig() {
    cp $1 $1.autobackup
}

get_mysql_key_buffer_size() {
    Default=
    Min=
    Suffix='M'

    if [[ $1 -gt $RamMin ]]; then 
	Result=$(($1 / 4))
    else
	Result=$(($1 / 8))
    fi
    echo "${Result}${Suffix}"
}

get_mysql_table_open_cache() {
    Default=64
    Min=
    Suffix=''

    if [[ $1 -gt $RamMin ]]; then 
	Result=256
    else
	Result=$Default
    fi
    echo "${Result}${Suffix}"
}

get_mysql_myisam_sort_buffer_size() {
	echo "$(($1 / 3))M"
}

get_mysql_innodb_buffer_pool_size(){	
	echo "$(($1 / 2))M"
}

regenerate_config(){
	TotalMem=`free -m | grep Mem | awk '{print $2}'`        # Total memory size in bytes
	AutoChangeConfig=`grep -o -P "^#Jelastic autoconfiguration mark." $MySQLConfigPath`
	key_buffer_size=$(get_mysql_key_buffer_size $TotalMem)
	table_open_cache=$(get_mysql_table_open_cache $TotalMem)
	myisam_sort_buffer_size=$(get_mysql_myisam_sort_buffer_size $TotalMem)
	innodb_buffer_pool_size=$(get_mysql_innodb_buffer_pool_size $TotalMem)
	NamesOfVariables="key_buffer_size table_open_cache myisam_sort_buffer_size innodb_buffer_pool_size"

	#Check autoconfiguration mark
	if [[ $AutoChangeConfig != "#Jelastic autoconfiguration mark." ]]; then
		log "Autoconfiguration mark not found. Skip autoconfig."
	else
		backupconfig $MySQLConfigPath
	for VariableName in ${NamesOfVariables}
		do
			MySQLConfigParametrName=${VariableName}
			MySQLConfigParametrValue=${!VariableName}
			sed -i 's/^'${MySQLConfigParametrName}'.*=.[0-9]*[a-zA-Z]*/'${MySQLConfigParametrName}' = '${MySQLConfigParametrValue}'/g' ${MySQLConfigPath}
#			echo "Parameter ${MySQLConfigParametrName} set to ${MySQLConfigParametrValue}"
		done
	/usr/bin/setfacl -m g:ssh-access:wr ${MySQLConfigPath} 2>&1 1>/dev/null;
	fi
}
regenerate_config
