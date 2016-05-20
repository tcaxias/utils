#!/bin/sh

[ -n "$MYSQL_USER" ] && MYSQL_USER=" -u $MYSQL_USER"
[ -n "$MYSQL_PASSWD" ] && MYSQL_PASSWD=" -p$MYSQL_PASSWD"

mysql="mysql $MYSQL_USER $MYSQL_PASSWD $MYOPTS"
$mysql -Nrse"select 1" > /dev/null || { echo "no mysql access using $mysql" && sleep 30s && exit 1; }

timeout=$TIME
[ -z "$timeout" ] && { echo "no TIME env var" && exit 1; }
sleep=60
#sleep=$(($timeout/2))

check_sql() {
    echo "select 1" | $mysql -Nrs || echo -1
}

check_slave() {
    $mysql -e'show slave status\G' | grep Seconds || echo -1
}

check_lag() {
    $mysql -e'show slave status\G' | grep Seconds | sed -r -e 's|.*: *([^ ]+) *|\1|'
}

check_galera() {
    echo "select min(x) from (select variable_value*1 x from information_schema.global_status where variable_name = 'WSREP_LOCAL_STATE' union all select 9 x) a" | $mysql -Nrs
}

start_service() {
    echo 'start listen' | supervisorctl -c /opt/supervisord.conf > /dev/null
}

stop_service() {
    echo 'stop listen' | supervisorctl -c /opt/supervisord.conf > /dev/null
}

while sleep $sleep
do
    lag=0
    state=0
    alive=$(check_sql)
    slave=$(check_slave)
    if [ $alive -lt 0 ]; then
        echo "counldn't connect to DB"
    elif [ "$slave" = "-1" ]; then
        state=$(check_galera)
    else
        lag=$(check_lag)
        [ "NULL" = "$lag" ] && lag=$timeout
    fi

    if [ $state -eq 4 ] || [ $state -eq 9 ] || [ $lag -lt $timeout ]; then
        $(start_service)
    else
        $(stop_service)
    fi
done
