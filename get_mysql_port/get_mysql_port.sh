#!/bin/sh

FILE=$1
[ -z "$FILE" ] && FILE="/etc/mysql/my.cnf"

exec grep -E '\s*port\s+=.*' $FILE | sed -E -e 's|.+= *([^ ]+).*|\1|g' |head -1
