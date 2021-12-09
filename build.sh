#/bin/bash

read -p "Server host (name or IP):" SERVER_HOST
read -p "MySQL Host: " MYSQL_HOST
read -p "MySQL Database: " MYSQL_DB
read -p "MySQL User: " MYSQL_USER
read -p "MySQL Password: " MYSQL_PASS

function pause() {
    read -p "Press enter..."
}

BASE=`pwd`
SERVER=$BASE/DarkflameServer
AM=$BASE/AccountManager

# MYSQL_HOST=localhost
# MYSQL_DB=lego
# MYSQL_USER=lego
# MYSQL_PASS=legouniverse

mysql -u root -p -h $MYSQL_HOST <<EOF
drop database if exists $MYSQL_DB;
drop user if exists '$MYSQL_USER'@'$MYSQL_HOST';
create database $MYSQL_DB;
create user '$MYSQL_USER'@'$MYSQL_HOST' identified by '$MYSQL_PASS';
grant all on $MYSQL_DB.* to '$MYSQL_USER'@'$MYSQL_HOST';
flush privileges;
EOF

# Install required deps. Not nearly complete yet.
sudo dnf install -y zlib-devel rar unrar gcc gcc-c++ make cmake python3 python3-pip sqlite wget git unzip
if [ ! -e $BASE/LEGO\ Universe\ \(unpacked\).rar ] ; then
    echo Downloading client
    wget https://archive.org/download/lego-universe-unpacked/LEGO%20Universe%20%28unpacked%29.rar
fi

if [ ! -e $BASE/navmeshes.zip ] ; then
    echo Downloading additional resources
    wget https://github.com/DarkflameUniverse/DarkflameServer/raw/main/resources/navmeshes.zip
fi

echo Cloning server source
git clone --recursive https://github.com/DarkflameUniverse/DarkflameServer
echo Cloning utils
git clone https://github.com/lcdr/utils.git
echo Cloning AccountManager
git clone https://github.com/DarkflameUniverse/AccountManager.git

echo "Building server..."
cd $BASE/DarkflameServer
mkdir build 
cd build
cmake ..
make
pause

echo Extracting resources from client archive
unrar x $BASE/LEGO\ Universe\ \(unpacked\).rar res/macros res/BrickModels res/chatplus_en_us.txt res/names res/maps locale/locale.xml res/cdclient.fdb
cd res
unzip $BASE/navmeshes.zip
pause

echo Converstion database
python3 $BASE/utils/utils/fdb_to_sqlite.py --sqlite_path CDServer.sqlite cdclient.fdb
echo Updating SQLite database
for SQL in  $SERVER/migrations/cdserver/0_nt_footrace.sql \
    $SERVER/migrations/cdserver/1_fix_overbuild_mission.sql \
    $SERVER/migrations/cdserver/2_script_component.sql ; do
    sqlite3 $SERVER/build/res/CDServer.sqlite < $SQL
done
pause

echo Applying database configuration
cd $SERVER/build
for INI in authconfig.ini  chatconfig.ini  masterconfig.ini  worldconfig.ini ; do
    sed -i "s/mysql_host=.*/mysql_host=$MYSQL_HOST/" $INI
    sed -i "s/mysql_database=.*/mysql_database=$MYSQL_DB/" $INI
    sed -i "s/mysql_username=.*/mysql_username=$MYSQL_USER/" $INI
    sed -i "s/mysql_password=.*/mysql_password=$MYSQL_PASS/" $INI
    sed -i "s/external_ip=.*/external_ip=$SERVER_HOST/" $INI
done
pause

echo Updating MySQL/MariaDB database
mysql --user=$MYSQL_USER --password=$MYSQL_PASS -h $MYSQL_HOST $MYSQL_DB < $SERVER/migrations/dlu/0_initial.sql
pause

echo Creating admin user
cd $SERVER/build
./MasterServer -a

echo Installing required deps for AccountManager
cd $AM
for PKG in `cat requirements.txt` ; do 
    #pip3 install --user $PKG
    PKGS="$PKGS $PKG"
done
pip3 install --user $PKGS

echo Writing AccountManager configuration
KEY=`echo $RANDOM | sha256sum | head -32 | cut -f 1 -d ' '`
echo "# credentials.py

# Make sure this is a long random string
SECRET_KEY = '$KEY'

# Replace instances of <> with the database credentials
DB_URL = 'mysql+pymysql://$MYSQL_USER:$MYSQL_PASS@$MYSQL_HOST/$MYSQL_DB'
" > credentials.py

echo "# resources.py

# Path to the logo image to display on the application
LOGO = 'logo/logo.png'

# Path to the privacy policy users have to agree to
PRIVACY_POLICY = 'policy/Privacy Policy.pdf'

# Path to the terms of use users have to agree to
TERMS_OF_USE = 'policy/Terms of Use.pdf'" > resources.py

if [ ! -e dlu_client.zip ] ; then
    echo Configuration client
    mkdir dlu_client
    cd dlu_client
    unrar e $BASE/LEGO\ Universe\ \(unpacked\).rar 
    sed -i "s/AUTHSERVERIP=0:.*/AUTHSERVERIP=0:$SERVER_HOST/" boot.cfg
    cd $BASE
    zip -r -9 dlu_client.zip dlu_client/*
    rm -rf dlu_client
fi

echo Build finished.
echo The server is available in $SERVER/build/MasterServer
echo The AccountManager is available in $AM