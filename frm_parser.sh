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
            
            
            if [ -f "$RT_definitions_directory/table_defs.h" ]; then
                cmd="rm $RT_definitions_directory/table_defs.h"
                log_debug "Running: $cmd"
                eval $cmd > /dev/null
                if [ ! $? ]; then 
                    log_error "$cmd"; 
                fi
            fi
            
            if [ -f "$RT_definitions_directory/table_defs.h.$db.$table" ]; then
                
                cmd="ln -sf $RT_definitions_directory/table_defs.h.$db.$table \
                    $RT_definitions_directory/table_defs.h"
                log_debug "Running: $cmd"
                eval $cmd > /dev/null
                if [ ! $? ]; then 
                    log_error "$cmd"; 
                fi
            else
                log_warning "$RT_definitions_directory/table_defs.h.$db.$table doesn not exists! skipping..."
            fi
            
            cmd="cd $RT_directory && make clean all"
            log_debug "Running: $cmd"
            eval $cmd > /dev/null
            if [ ! $? ]; then log_error "$cmd"; fi
            
            cmd="$RT_directory/constraints_parser \
                -5Uf $RT_directory/$PAGES_DIRECTORY/FIL_PAGE_INDEX/0-$index_id \
                -b $RT_directory/$PAGES_DIRECTORY/FIL_PAGE_TYPE_BLOB 2> \
                $RT_directory/dumps/import/$db.$table.sql > $RT_directory/dumps/$db/$table"
            
            log_debug "Running: $cmd"
            eval $cmd > /dev/null
            if [ ! $? ]; then log_error "$cmd"; fi
            
            log_info "Done..."
        fi
    done
}


ARGS=$(getopt -l "create-dummy-tables,copy-frms,create-defs,parse-tables,pages-directory,source-datadir:,tables-file:,help" -n "frm_parser.sh" -- -- "$@");

eval set -- "$ARGS";



TABLES_FILE=1
flag_copy_frms=1
flag_create_dummy_tables=1
flag_create_defs=1
flag_parse_tables=1
SOURCE_DATADIR=1
PAGES_DIRECTORY=1

while true; do
  case "$1" in
    --create-dummy-tables) flag_create_dummy_tables=0 ;;
    --copy-frms) flag_copy_frms=0 ;;
    --create-defs) flag_create_defs=0 ;;
    --parse-tables) flag_parse_tables=0 ;;
    --pages-directory) PAGES_DIRECTORY="$2"; shift ;;
    --source-datadir) SOURCE_DATADIR="$2"; shift ;;
    --tables-file) TABLES_FILE="$2"; shift ;;
    --help) p_help ;;
    --) break; ;;
    esac
    shift
done

if [ $flag_create_dummy_tables -eq 0 ]; then
    log_info "Creating dummy tables"
    if [ -r $TABLES_FILE ]; then
        create_dummy_tables
    else
        log_error "Create dummy tables require the option --tables-file."
    fi
fi

if [ $flag_parse_tables -eq 0 ]; then
    log_info "Creating dummy tables"
    if [ -r $TABLES_FILE -a -d $PAGES_DIRECTORY ]; then
        parse_tables
    else
        log_error "Parse tables requires the option --tables-file and --pages-directory"
    fi
fi


if [ $flag_create_defs -eq 0 ]; then
    log_info "Create tables definitions"
    if [ -a -r $TABLES_FILE ]; then
        create_defs
    else
        log_error "Create table definitions require the option --tables-file."
    fi
fi

if [ $flag_copy_frms -eq 0 ]; then 
    log_info "copy frms"
    
    if [ -r $TABLES_FILE -a -d $SOURCE_DATADIR ]; then
        copy_frms
    else
        log_error "Copy frm's requires the option --tables-file and --source-datadir"
    fi
fi