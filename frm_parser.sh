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
        
        cmd="$RT_BIN_create_defs --host=127.0.0.1 --user=root --port=$TEMP_port --socket=$TEMP_socket --db=$db --table=$table > $RT_definitions_directory/table_defs.h.$db.$table"
        log_debug "$cmd"
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

get_table_id(){
    db=$1
    table=$2
    id=$($TEMP_BIN_mysql -BN $TEMP_mysql_options -e "SELECT id FROM test.SYS_TABLES WHERE NAME='$db/$table'")
    echo $id
}

get_index_id(){
    table_id=$1
    id=$($TEMP_BIN_mysql -BN $TEMP_mysql_options -e "select ID from test.SYS_INDEXES WHERE NAME IN ('PRIMARY', 'GEN_CLUST_INDEX') AND TABLE_ID=$table_id")
    echo $id
}

parse_tables(){

    $table=$1
    
    for s in $(cat $TABLES_FILE); do
        db=$(get_db "$s")
        table=$(get_table "$s")
        table_id=$(get_table_id $db $table)
        index_id=$(get_index_id $table_id)
        
        log_info "Running for: \nDB:$db\nTable:$table\nID:$table_id"
        
        
        if [ ! -d "$RT_directory/dumps/$db/" ]; then
            cmd="mkdir $RT_directory/dumps/$db/"
            log_debug "Running: $cmd"
            eval $cmd > /dev/null
            if [ ! $? ]; then log_error "$cmd"; fi
        fi
            
        #Check if the info file exists
        cmd="cd $RT_directory"
        
        if [ -f "$RT_definitions_directory/table_defs.h.$db.$table" ]; then
            cmd="rm $RT_directory/constraints_parser"
            log_debug "Running: $cmd"
            eval $cmd > /dev/null
            if [ ! $? ]; then log_error "$cmd"; fi
            
            cmd="rm $RT_definitions_directory/table_defs.h"
            log_debug "Running: $cmd"
            eval $cmd > /dev/null
            if [ ! $? ]; then log_error "$cmd"; fi
                        
            cmd="ln -s $RT_definitions_directory/table_defs.h.$db.$table $RT_definitions_directory/table_defs.h"
            log_debug "Running: $cmd"
            eval $cmd > /dev/null
            if [ ! $? ]; then log_error "$cmd"; fi
             
            cmd="cd $RT_directory && make constraints_parser"
            log_debug "Running: $cmd"
            eval $cmd > /dev/null
            if [ ! $? ]; then log_error "$cmd"; fi
            
            cmd="$RT_directory/constraints_parser -5 \
                -f $RT_directory/pages-1377799050/FIL_PAGE_INDEX/0-$index_id \
                -b $RT_directory/pages-1377799050/FIL_PAGE_TYPE_BLOB 2> $RT_directory/dumps/import/$db.$table.sql > $RT_directory/dumps/$db/$table"
            eval $cmd 
            if [ ! $? ]; then log_error "$cmd"; fi
            
            log_info "Done..."
        fi
    done
}


ARGS=$(getopt -l "create-dummy-tables,copy-frms,create-defs,parse-tables,source-datadir:,tables-file:,help" -n "frm_parser.sh" -- -- "$@");

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
    --parse-tables) flag_parse_tables=0 ;;
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

if [ $flag_parse_tables -eq 0 -a -r $TABLES_FILE ]; then
    log_info "Creating dummy tables"
    parse_tables
fi


if [ $flag_create_defs -eq 0 -a -r $TABLES_FILE  ]; then
    log_info "Create defs"
    
    create_defs    
fi

if [ $flag_copy_frms -eq 0 -a -r $TABLES_FILE -a -d $SOURCE_DATADIR ]; then
    log_info "copy frms"
    
    copy_frms
fi