#!/bin/sh

hostname_resolv(){
    DB_HOST=$1
    # check if db hostname resolvs
    getent hosts ${DB_HOST} > /dev/null
    if [ $? -ne 0 ]
    then
        echo "ERROR : unable to get ip address for host ${DB_HOST}"
        echo "Did you set the DB_HOST environment variable ?"
        return 1
    fi

    return 0
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
        return 2
    fi

    return 0
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

    return 0
}


auth_check() {
    DB_HOST=$1
    DB_USER=$2
    DB_PASSWORD=$3
    # check credentials
    mysql -h ${DB_HOST} -u ${DB_USER} -p${DB_PASSWORD} -e"quit"
    if [ $? -ne 0 ]
    then
        echo "ERROR: authentication problem. Are DB_USER & DB_PASSWORD set ?"
        return 3
    fi

    return 0
}

existence_check() {
    DB_HOST=$1
    DB_USER=$2
    DB_PASSWORD=$3
    DB_NAME=$4

    # check if database exists
    mysqlshow -h ${DB_HOST} --user=${DB_USER} --password=${DB_PASSWORD} ${DB_NAME} | grep -v Wildcard | grep -o ${DB_NAME}
    if [ $? -ne 0 ]
    then
        echo "ERROR: database ${DB_NAME} not found. Is DB_NAME set ?"
        return 4
    fi

    return 0
}

global_check() {
    DB_HOST=${1:-'mysql'}
    DB_USER=${2:-'user'}
    DB_PASSWORD=${3:-'password'}
    DB_NAME=${4:-'database'}
    INIT_DB=${5:-'false'}

    hostname_resolv $DB_HOST || exit $?
    hostname_connectivity $DB_HOST || exit $?

    if [ $INIT_DB == "true" ]
    then
        db_initialize $DB_HOST $DB_ROOT_PASSWORD || exit $?
    fi

    type mysql 2>/dev/null
    if [ $? == 0 ]
       then
           auth_check $DB_HOST $DB_USER $DB_PASSWORD
           test $? != 0 && exit $?
    fi
    type mysqlshow 2>/dev/null
    if [ $? == 0 ]
       then
           existence_check  $DB_HOST $DB_USER $DB_PASSWORD $DB_NAME
           test $? != 0 && exit $?
    fi


    return 0
}
