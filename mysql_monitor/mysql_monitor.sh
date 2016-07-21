#!/bin/sh

[ -n "$MYSQL_USER" ] && MYSQL_USER=" -u $MYSQL_USER"
[ -n "$MYSQL_PASSWD" ] && MYSQL_PASSWD=" -p$MYSQL_PASSWD"

mysql="mysql $MYSQL_USER $MYSQL_PASSWD $MYOPTS"
$mysql -Nrse"select 1" > /dev/null || { echo "no mysql access using $mysql" && sleep 30s && exit 1; }

[ -z "$TIME" ] && TIME=60
timeout=$TIME
#sleep=30
sleep=$(($timeout/2))

check_sql() {
    echo "select 1" | $mysql -Nrs || echo -1
}

check_slave() {
    $mysql -e'show slave status\G' | grep Seconds || echo -1
}

check_tzs() {
    echo "select count(1) from mysql.time_zone_name" | $mysql -Nrs || echo -1
}

check_lag() {
    $mysql -e'show slave status\G' | grep Seconds | sed -r -e 's|.*: *([^ ]+) *|\1|'
}

check_galera() {
    echo "select min(x) from (select variable_value*1 x from information_schema.global_status where variable_name = 'WSREP_LOCAL_STATE' union all select 9 x) a" | $mysql -Nrs
}

start_listen() {
    echo 'start listen' | supervisorctl -c /usr/local/bin/supervisord.conf > /dev/null
}

stop_listen() {
    echo 'stop listen' | supervisorctl -c /usr/local/bin/supervisord.conf > /dev/null
}

while sleep $sleep
do
    lag=0
    state=0
    alive=$(check_sql)
    slave=$(check_slave)
    if [ $alive -lt 0 ]; then
        echo "can't connect to DB"
    elif [ "$slave" = "-1" ]; then
        state=$(check_galera)
    else
        lag=$(check_lag)
        [ "NULL" = "$lag" ] && lag=$timeout
    fi

    if [ "0$state" -eq 4 ] || [ "0$state" -eq 9 ] || [ "0$lag" -lt "0$timeout" ]; then
        tzs=$(check_tzs)
        if [ "0tsz" -lt 100 ]; then
            $(load_tzs)
        fi
        if [ "0tsz" -gt 100 ]; then
            $(start_listen)
        else
            $(stop_listen)
        fi
    else
        $(stop_listen)
    fi
done
