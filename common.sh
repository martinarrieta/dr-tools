#!/bin/sh


get_db(){
  echo $(echo $1 | awk -F. '{print $1}')
}

get_table(){
     echo $(echo $1 | awk -F. '{print $2}')
}

log_info() {
    echo "[INFO] $1"
}

log_debug() {
    if [ $DEBUG ]; then
        echo "[DEBUG] $1"
    fi
}

log_error() {
    echo "[Error] $1"
    exit 1
}

p_help(){

    echo "help!!"

}



temp_run_sql(){


    if [ ! -x $TEMP_BIN_mysql ]; then
        log_error "$TEMP_BIN_mysql does not exists"
    fi
    
    cmd="$TEMP_BIN_mysql $TEMP_mysql_options -e '$1'"
    
    log_debug "Running: $cmd"
    
    
    eval $cmd 
    
    out=$?
    # &> $LOGFILE
    
    if [[ $? ]]; then
        log_error "Error runnign $1"
    fi
}
