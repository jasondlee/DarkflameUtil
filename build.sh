#/bin/bash

#read -p "MySQL Host: " MYSQL_HOST
#read -p "MySQL Database: " MYSQL_DB
#read -p "MySQL User: " MYSQL_USER
#read -p "MySQL Password: " MYSQL_PASS

function pause() {
    read -p "Press enter..."
}

BASE=`pwd`
MYSQL_HOST=localhost
MYSQL_DB=lego
MYSQL_USER=lego
MYSQL_PASS=legouniverse

mysql -u root -p -h $MYSQL_HOST <<EOF
drop database if exists $MYSQL_DB;
drop user if exists '$MYSQL_USER'@'$MYSQL_HOST';
create database $MYSQL_DB;
create user '$MYSQL_USER'@'$MYSQL_HOST' identified by '$MYSQL_PASS';
grant all on $MYSQL_DB.* to '$MYSQL_USER'@'$MYSQL_HOST';
flush privileges;
EOF

sudo dnf install zlib-devel unrar
if [ ! -e $BASE/LEGO\ Universe\ \(unpacked\).rar ] ; then
    wget https://archive.org/download/lego-universe-unpacked/LEGO%20Universe%20%28unpacked%29.rar
fi

if [ ! -e $BASE/navmeshes.zip ] ; then
    wget https://github.com/DarkflameUniverse/DarkflameServer/raw/main/resources/navmeshes.zip
fi

git clone --recursive https://github.com/DarkflameUniverse/DarkflameServer
git clone https://github.com/lcdr/utils.git
git clone https://github.com/DarkflameUniverse/AccountManager.git

SERVER=$BASE/DarkflameServer
AM=$BASE/AccountManager

cd $BASE/DarkflameServer
mkdir build 
cd build
cmake ..
make
pause

unrar x $BASE/LEGO\ Universe\ \(unpacked\).rar res/macros res/BrickModels res/chatplus_en_us.txt res/names res/maps locale/locale.xml res/cdclient.fdb
pause

cd res
unzip $BASE/navmeshes.zip
pause

python3 $BASE/utils/utils/fdb_to_sqlite.py --sqlite_path CDServer.sqlite cdclient.fdb
pause


cd $SERVER/build
for INI in authconfig.ini  chatconfig.ini  masterconfig.ini  worldconfig.ini ; do
    sed -i "s/mysql_host=.*/mysql_host=$MYSQL_HOST/" $INI
    sed -i "s/mysql_database=.*/mysql_database=$MYSQL_DB/" $INI
    sed -i "s/mysql_username=.*/mysql_username=$MYSQL_USER/" $INI
    sed -i "s/mysql_password=.*/mysql_password=$MYSQL_PASS/" $INI
done
pause


for SQL in $SERVER/migrations/dlu/0_initial.sql \
    $SERVER/migrations/cdserver/0_nt_footrace.sql \
    $SERVER/migrations/cdserver/1_fix_overbuild_mission.sql \
    $SERVER/migrations/cdserver/2_script_component.sql ; do
    mysql --user=$MYSQL_USER --password=$MYSQL_PASS -h $MYSQL_HOST $MYSQL_DB < $SQL
done
pause

cd $SERVER/build
./MasterServer -a

cd $AM
for PKG in `cat requirements.txt` ; do 
    #pip3 install --user $PKG
    PKGS="$PKGS $PKG"
done
pip3 install --user $PKGS

KEY=`echo $RANDOM | sha256sum | head -32 | cut -f 1 -d ' '`

echo "# credentials.py

# Make sure this is a long random string
SECRET_KEY = '$KEY'

# Replace instances of <> with the database credentials
DB_URL = 'mysql+pymysql://$MYSQL_USER:$MYSQL_PASS@$MYSQL_HOST/$MYSQL_DB'
" > credentials.py