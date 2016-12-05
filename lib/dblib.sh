#!/bin/sh

hostname_resolv(){
    DB_HOST=$1
    # check if db hostname resolvs
    getent hosts ${DB_HOST} > /dev/null
    if [ $? -ne 0 ]
    then
        echo "ERROR : unable to get ip address for host ${DB_HOST}"
        echo "Did you set the DB_HOST environment variable ?"
        exit 1
    fi

    exit 0
}

hostname_connectivity() {
    DB_HOST=$1
    DB_PORT=3306
    # check if connexion to do is ok
    #echo "checking if db server is reachable"
    /usr/local/bin/wait-for-it.sh -q -t 300 ${DB_HOST}:${DB_PORT}
    #timeout 1 bash -c 'cat < /dev/null > /dev/tcp/${DB_HOST}/${DB_PORT}'
    if [ $? -ne 0 ]
    then
        echo "network connectivity to db is not ok"
        exit 2
    fi
}

db_initialize() {
    DB_HOST=$1
    DB_ROOT_PASSWORD=${2:-'no-root-password'}

    echo "creating db user"
    mysql -u root -p${DB_ROOT_PASSWORD} -h ${DB_HOST} -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';"

    echo "creating database"
    mysql -u root -p${DB_ROOT_PASSWORD} -h ${DB_HOST} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"

    echo "granting access"
    mysql -u root -p${DB_ROOT_PASSWORD} -h ${DB_HOST} -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';"

    mysql -u root -p${DB_ROOT_PASSWORD} -h ${DB_HOST} -e "flush privileges;"
}


auth_check() {
    DB_HOST=$1
    DB_USER=$2
    DB_USER=$3
    # check credentials
    mysql -h ${DB_HOST} -u ${DB_USER} -p${DB_PASSWORD} -e"quit"
    if [ $? -ne 0 ]
    then
        echo "ERROR: authentication problem. Are DB_USER & DB_PASSWORD set ?"
        exit 3
    fi
}

existence_check() {
    DB_HOST=$1
    DB_USER=$2
    DB_USER=$3

    # check if database exists
    mysqlshow -h ${DB_HOST} --user=${DB_USER} --password=${DB_PASSWORD} ${DB_NAME} | grep -v Wildcard | grep -o ${DB_NAME}
    if [ $? -ne 0 ]
    then
        echo "ERROR: database ${DB_NAME} not found. Is DB_NAME set ?"
        exit 4
    fi

}
