from __future__ import print_function
from random import SystemRandom
from sys import maxsize, argv, exit
import mysql.connector.pooling as my
from flask import Flask,g
app = Flask(__name__)
my_pool = my.MySQLConnectionPool(
    option_files="/root/.my.cnf",
    autocommit=True,
    pool_name="Grand_Duchess_Anastasia_Nikolaevna_of_Russia",
    pool_size=1)

# GENERAL HELPER FUNCTIONS
def rnd(l):
    return SystemRandom().choice(l)

def bool_to_response(response):
    if response==True:
        response = ("True",200)
    elif response==False:
        response = ("False",rnd((418,451)))
    return response

# CONNECTION MANAGEMENT ON THE MIDDLEWARE
@app.before_request
def fetch_connection():
    g.cnx = my_pool.get_connection()
    g.cursor = g.cnx.cursor(dictionary=True)

@app.after_request
def release_connection(response):
    g.cursor.close()
    g.cnx.close()
    return response

# DATABASE FUNCTIONS
def read_only():
    g.cursor.execute("show variables like 'read_only'")
    ret = str(next(g.cursor)[u'Value'])
    return False if ret == 'OFF' else True

def replica_status(max_lag = maxsize):
    g.cursor.execute("show slave status")
    try:
        lag = int(next(g.cursor)[u'Seconds_Behind_Master'])
        return (lag < max_lag, lag)
    except:
        return False

def is_replica():
    g.cursor.execute("show slave status")
    try:
        return (True,str(next(g.cursor)[u'Master_Host']))
    except:
        return False

def serving_binlogs():
    g.cursor.execute("""select count(*) as n
                    from information_schema.processlist
                    where command = 'Binlog Dump'""")
    return int(next(g.cursor)[u'n'])

def galera_cluster_state():
    g.cursor.execute("""select variable_value as v
                        from information_schema.global_status
                        where variable_name like 'wsrep_local_state' = 4""")
    try:
        return (True, str(next(g.cursor)[u'v']))
    except:
        return False

# STATUS ROUTES
@app.route("/status/rw")
def rw():
    return bool_to_response(
        not read_only())

@app.route("/status/ro")
def ro():
    return bool_to_response(
        read_only())

@app.route("/status/single")
def single():
    return(bool_to_response(
        not read_only() and
        not is_replica() and
        not serving_binlogs()))

@app.route("/status/leader")
def leader():
    return(bool_to_response(
        not is_replica() and
        serving_binlogs()))

@app.route("/status/follower")
def follower():
    return(bool_to_response(
            is_replica()))

@app.route("/status/topology")
def topology():
    return(bool_to_response(
            (not replica_status() and
            serving_binlogs())
        or
            is_replica()
        ))

# ROLES ROUTES
@app.route("/role/master")
def master():
    return(bool_to_response(
        not read_only() and
        not is_replica()))

@app.route("/role/replica")
def replica():
    return(bool_to_response(
        read_only() and
        replica_status()))

@app.route("/role/replica/<int:lag>")
def lag():
    return(bool_to_response(
        read_only() and
        replica_status(lag)))

@app.route("/role/galera")
def galera():
    return(bool_to_response(
        galera_cluster_state()))

# READ ROUTES
@app.route("/read/galera/state")
def galera_state():
    state = galera_cluster_state()
    if not state:
        return(bool_to_response(state))
    else:
        return(state)

@app.route("/read/replication/lag")
def read_replication_lag():
    state = is_replica()
    status = replica_status()
    if not state:
        return(bool_to_response(state))
    else:
        return(status[1],200)

@app.route("/read/replication/master")
def read_replication_master():
    state = is_replica()
    status = replica_status()
    if not state:
        return(bool_to_response(state))
    else:
        return(status[1],200)

@app.route("/read/replication/replicas_count")
def read_replication_replicas_count():
    state = serving_binlogs()
    if not state:
        return(bool_to_response(state))
    else:
        return(state,200)

if __name__ == "__main__":
    port = 3307
    if len(argv) > 1:
        try:
            port = int(argv[1])
        except:
            exit('Unreadable port number on first argument')
    app.run(host='0.0.0.0',port=port)
