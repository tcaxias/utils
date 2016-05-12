#!/bin/sh

DIR=$(dirname $0)
FILE=$@
PORT=$($DIR/get_mysql_port.sh $@)
[ "$PORT" -gt 0 ] || exit 1
PORT=$(($PORT+1))

exec dropbear -R -F -E -m -w -s -j -k -p $PORT
