#!/bin/bash

. common.sh

. drtools.conf

create_dummy_tables(){

    for s in $(cat $TABLES_FILE); do
        log_debug "Creating schema"
        db=$(get_db "$s")
        table=$(get_table "$s")
        temp_run_sql "CREATE DATABASE IF NOT EXISTS $db"
        temp_run_sql "CREATE TABLE IF NOT EXISTS $db.$table(i int) ENGINE=InnoDB"
    done

}

create_defs(){

    for s in $(cat $TABLES_FILE); do
        db=$(get_db "$s")
        table=$(get_table "$s")
        
        cmd="$RT_BIN_create_defs --host=127.0.0.1 --user=root --port=$TEMP_port --db=$db --table=$table > $RT_definitions_directory/table_defs.h.$db.$table"
        eval $cmd 
        
    done

}

copy_frms(){

    if [ ! -d "$TEMP_datadir" ]; then
        log_error "$TEMP_datadir does not exist"
    fi
    
    for s in $(cat $TABLES_FILE); do
        log_debug "Creating schema"
        db=$(get_db "$s")
        table=$(get_table "$s")
        if [ -r "$SOURCE_DATADIR/$db/$table.frm" -a "$TEMP_datadir/$db/$table.frm" ]; then
            cmd="cp -f $SOURCE_DATADIR/$db/$table.frm $TEMP_datadir/$db/$table.frm"
            log_debug "Running $cmd"
            eval $cmd 
        fi
    done

}




if ! options=$(getopt -o crdht: -l create-instance,run-temp-instance,help,tables-file: -- "$@")
then
    p_help
    exit 1
fi

set -- $options

TABLES_FILE=1
flag_copy_frms=1
flag_create_dummy_tables=1
SOURCE_DATADIR=1
flag_create_defs=1

while [ $# -gt 0 ] 
do
  case "$1" in
    --create-dummy-tables ) flag_create_dummy_tables=0 ;;
    --copy-frms ) flag_copy_frms=0 ;;
    --create-defs ) flag_create_defs=0 ;;
    --source-datadir ) SOURCE_DATADIR="$2"; shift ;;
    --help ) p_help ;;
    --tables-file ) TABLES_FILE="$2"; shift ;;
    (--)  ;;
    (*)  ;;  
  esac
  shift
done

if [ $flag_create_dummy_tables -eq 0 -a -r $TABLES_FILE  ]; then
    create_dummy_tables
    
fi

if [ $flag_create_defs -eq 0 -a -r $TABLES_FILE  ]; then
    create_defs    
fi


if [ $flag_copy_frms -eq 0 -a -r $TABLES_FILE -a -d $SOURCE_DATADIR ]; then
    copy_frms
fi