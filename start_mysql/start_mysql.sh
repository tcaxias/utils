#!/bin/sh
# I read mysql_state as a

[ -f /var/lib/mysql/mysql/mysql.frm ] || \
    mysql_install_db

mkdir -p \
    /var/lib/mysql \
    /var/log/mysql \
    /var/run/mysqld/tmp \
    /run/mysqld

chown mysql.mysql -R \
    /var/lib/mysql \
    /var/log/mysql \
    /var/run/mysqld \
    /run/mysqld

exec mysqld_safe --plugin-load=server_audit.so $@
