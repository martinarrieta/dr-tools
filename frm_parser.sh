#!/bin/sh

. ./common.sh

. ./drtools.conf

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

ARGS=$(getopt -l "create-dummy-tables,copy-frms,create-defs,source-datadir:,tables-file:,help" -n "frm_parser.sh" -- -- "$@");

eval set -- "$ARGS";



TABLES_FILE=1
flag_copy_frms=1
flag_create_dummy_tables=1
SOURCE_DATADIR=1
flag_create_defs=1

while true; do
  case "$1" in
    --create-dummy-tables) flag_create_dummy_tables=0 ;;
    --copy-frms) flag_copy_frms=0 ;;
    --create-defs) flag_create_defs=0 ;;
    --source-datadir) SOURCE_DATADIR="$2"; shift ;;
    --tables-file) TABLES_FILE="$2"; shift ;;
    --help) p_help ;;
    --) break; ;;
    esac
    shift
done

if [ $flag_create_dummy_tables -eq 0 -a -r $TABLES_FILE ]; then
    log_info "Creating dummy tables"
    create_dummy_tables
fi

if [ $flag_create_defs -eq 0 -a -r $TABLES_FILE  ]; then
    log_info "Create defs"
    
    create_defs    
fi

if [ $flag_copy_frms -eq 0 -a -r $TABLES_FILE -a -d $SOURCE_DATADIR ]; then
    log_info "copy frms"
    
    copy_frms
fi