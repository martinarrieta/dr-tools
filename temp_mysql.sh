#!/bin/sh

./common.sh

./drtools.conf


start_temporal_instance(){

    if [ $FORCE_RECOVERY -eq 0 ]; then
        FR="--innodb-force-recovery=6"
    else
        FR=""
    fi
    
    cmd="$TEMP_BIN_mysqld --basedir=$TEMP_basedir --bind-address=127.0.0.1 \
        --socket=$TEMP_datadir/mysql.sock --datadir=$TEMP_datadir \
        --user=$TEMP_user --port=$TEMP_port --pid-file=$TEMP_pidfile $FR"
    if [ $DEBUG ]; then
        log_debug "Running: $cmd" 
    fi
    
    if [ ! -x $TEMP_BIN_mysqld ]; then
        log_error "$TEMP_BIN_mysqld does not exists"
    fi
    
    eval $cmd &
    
    if [ ! $? ]; then
        log_error "Error running "
    fi
}

stop_temporal_instance(){

    cmd="$TEMP_BIN_mysqladmin $TEMP_mysql_options shutdown"
    if [ $DEBUG ]; then
        log_debug "Running: $cmd" 
    fi
    
    if [ ! -x $TEMP_BIN_mysqladmin ]; then
        log_error "$TEMP_BIN_mysqladmin does not exists"
    fi
    
    eval $cmd & 
    
    if [ ! $? ]; then
        log_error "Error running "
    fi
}

initialize_temporal_instance(){
    if [ -d $TEMP_datadir ]; then
        log_error "Directory $TEMP_datadir already exists"
    fi
    
    if [ ! -x $TEMP_BIN_mysql_install_db ]; then
        log_error "$TEMP_BIN_mysql_install_db does not exists"
    fi
    
    if mkdir $TEMP_datadir && chown $TEMP_user $TEMP_datadir ; then
        $TEMP_BIN_mysql_install_db --datadir=$TEMP_datadir --user=$TEMP_user --basedir=$TEMP_basedir
        if [ $? ]; then
            log_info "Instance created succesufuly"
        else
            log_error "Error creating the instance"
        fi
    else
        log_error "Error creating the directory $TEMP_datadir"
    fi
}


temporal_instance_isrunning(){
    if [ -f $TEMP_pidfile ]; then
        ps xa | grep mysqld | grep "^$(cat $TEMP_pidfile)" > /dev/null 2>&1
        if [ $? ]; then
            return 0
        else
            rm $TEMP_pidfile
            return 1
        fi 
    else
        return 1
    fi
}
status_temporal_instance(){
    tmp=$(temporal_instance_isrunning)
    if [ $tmp -eq 0 ] ; then
        log_info "Instance is running in port: $TEMP_port and the pid is $(cat $TEMP_pidfile)"
    else
        log_info "Instance is not running."
    fi
    
}

ARGS=$(getopt -l "start,recovery,stop,init,status,help" -n "temp_mysql.sh" -- -- "$@");

eval set -- "$ARGS";

FORCE_RECOVERY=1

while true; do
  case "$1" in
    --start ) start_temporal_instance ;;
    --recovery ) FORCE_RECOVERY=0; start_temporal_instance ;;
    --stop ) stop_temporal_instance ;;
    --init ) initialize_temporal_instance ;;
    --status ) status_temporal_instance ;;
    --help ) p_help ;;
    --) break; ;;
    esac
    shift
done

