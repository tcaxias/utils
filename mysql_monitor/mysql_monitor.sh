#!/bin/sh

mysql="mysql -u$MYSQL_USER -p$MYSQL_PASSWD $MYOPTS"
$mysql -Nrse"select 1" > /dev/null || { echo "no mysql access using $mysql" && exit 1; }

timeout=$TIME
[ -z "$timeout" ] && { echo "no TIME env var" && exit 1; }
sleep=$(($timeout/2))

check_sql() {
    echo "select variable_value*1000 from information_schema.global_status where variable_name='SLAVE_HEARTBEAT_PERIOD'" | $mysql -Nrs || echo -1
}

check_slave() {
    $mysql -e'show slave status\G' | grep Seconds | sed -r -e 's|.*: *([^ ]+) *|\1|'
}

check_galera() {
    echo "select min(x) from (select variable_value*1 x from information_schema.global_status where variable_name = 'WSREP_LOCAL_STATE' union all select 9 x) a" | $mysql -Nrs
}

start_service() {
    echo 'start dropbear' | supervisorctl -c /opt/supervisord.conf
}

stop_service() {
    echo 'stop dropbear' | supervisorctl -c /opt/supervisord.conf
}

while sleep $sleep
do
    lag=0
    state=0
    slave=$(check_sql)
    if [ $slave -lt 0 ]; then
        echo "counldn't connect to DB"
    elif [ $slave -gt 0 ]; then
        lag=$(check_slave)
        [ "NULL" = "$lag" ] && lag=$timeout
    else
        state=$(check_galera)
    fi

    if [ $state -eq 4 ] || [ $state -eq 9 ] || [ $lag -le $timeout ]; then
        $(start_service)
    else
        $(stop_service)
    fi
done
