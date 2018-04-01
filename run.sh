#!/bin/sh

#################################################################################################
# TIME SYNC
#################################################################################################
ntpd -s

#################################################################################################
# APACHE
#################################################################################################
echo "Clearing any old processes..."
rm -f /run/apache2/apache2.pid
rm -f /run/apache2/httpd.pid

echo "Starting Apache..."
httpd

#################################################################################################
# MYSQL
#################################################################################################

# install locally on localhost
if [ "${MYSQL_HOST}" == "localhost" ]; then
    MYSQL_DATA="/var/lib/mysql"

    if [[ ! -d $MYSQL_DATA/mysql ]]; then
        echo "Installing MariaDB ..."
        mysql_install_db --user=mysql --datadir=/var/lib/mysql &> /dev/null

        # run mysql daemon
        (/usr/bin/mysqld_safe --datadir="/var/lib/mysql" &) && sleep 3

        # create user & database
        echo "Creating database & user..."
        mysql -u root -e "CREATE DATABASE ${MYSQL_BASE};"
        mysql -u root -e "CREATE USER ${MYSQL_USER}@${MYSQL_HOST} IDENTIFIED BY '${MYSQL_PASS}';"
        mysql -u root -e "GRANT ALL PRIVILEGES ON ${MYSQL_BASE}.* TO ${MYSQL_USER}@localhost;"

        # import sql file
        mysql -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_BASE} < /app/public/dustcloud/dustcloud.sql
    else
        # run mysql daemon
        (/usr/bin/mysqld_safe --datadir="/var/lib/mysql" &) && sleep 3
    fi
fi

#################################################################################################
# DUSTCLOUD
#################################################################################################

# variables
DUSTCLOUD=/app/public/dustcloud
WWWDIR=$DUSTCLOUD/www

# copy config
cp $WWWDIR/config.php.dist $WWWDIR/config.php

# modify php config
sed -i "s/DB_HOST = 'localhost'/DB_HOST = '${MYSQL_HOST}'/g" $WWWDIR/config.php
sed -i "s/DB_USER = 'user123'/DB_USER = '${MYSQL_USER}'/g" $WWWDIR/config.php
sed -i "s/DB_PASS = ''/DB_PASS = '${MYSQL_PASS}'/g" $WWWDIR/config.php
sed -i "s/DB_NAME = 'dustcloud'/DB_NAME = '${MYSQL_BASE}'/g" $WWWDIR/config.php
sed -i "s/http:\/\/localhost:1121\//http:\/\/{host}:1121\//g" $WWWDIR/config.php

sed -i "s/CMD_SERVER/str_replace('{host}', \$_SERVER['SERVER_NAME'], CMD_SERVER)/g" $WWWDIR/show.php

# modify python server
sed -i "s/pymysql.connect(\"localhost\", \"dustcloud\", \"\", \"dustcloud\")/pymysql.connect(\"${MYSQL_HOST}\", \"${MYSQL_USER}\", \"${MYSQL_PASS}\", \"${MYSQL_BASE}\")/g" $DUSTCLOUD/server.py
sed -i "s/my_cloudserver_ip = \"10.0.0.1\"/my_cloudserver_ip = \"${SERVER_IP}\"/g" $DUSTCLOUD/server.py
sed -i "s/host=\"localhost\"/host=\"0.0.0.0\"/g" $DUSTCLOUD/server.py

# run server
echo "Starting Dustcloud..."
/usr/bin/python3 -u $DUSTCLOUD/server.py --enable-live-map