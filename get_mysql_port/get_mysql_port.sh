#!/bin/sh

FILES=$@
[ -z "$FILES" ] && FILES="/etc/mysql/*/my.cnf"
[ -e "$FILES" ] || FILES="/etc/mysql/my.cnf"

exec grep -E '\s*port\s+=.*' $FILES | sed -E -e 's|.+= *([^ ]+).*|\1|g' | head -1 | grep -E -e '$' || echo 3306
