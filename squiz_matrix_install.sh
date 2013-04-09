#!/bin/bash

#### Root URL for the Squiz Matrix site - DO NOT include a trailing slash!
ROOT_URL="192.168.163.131"
#### Email address for Squiz Matrix confirguration
DEFAULT_EMAIL="nic@zedsaid.com"
#### The Path to the Squiz Matrix folder - DO NOT include trailing slash!
PATH_TO_MATRIX="/home/websites"
#### The Apache User
APACHE_USER="www-data"
#### The Version of Squiz Matrix to install
SQUIZ_MATRIX_VERSION="mysource_4-14-1"
#################################
#################################
#################################

echo "---- Updating apt-get"
apt-get update

echo "---- Installing packages"
apt-get -y install apache2 postgresql-8.4 php5 php5-cli php5-pgsql php-pear php5-curl php5-ldap php5-gd postfix cvs curl vim pdftohtml antiword git unzip php5-pspell tidy

echo "---- Installing PEAR"
pear upgrade PEAR
pear install MDB2 Mail Mail_Mime XML_HTMLSax XML_Parser Text_Diff HTTP_Client Net_URL I18N_UnicodeNormalizer Mail_mimeDecode Mail_Queue HTTP_Request Image_Graph-0.8.0 Image_Color Image_Canvas-0.3.4 Numbers_Roman Numbers_Words-0.16.4 pear/MDB2#pgsql

echo "---- Making Directory"
mkdir $PATH_TO_MATRIX
cd $PATH_TO_MATRIX

echo "---- Getting Squiz Matrix Source Code"
curl -O http://public-cvs.squiz.net/cgi-bin/viewvc.cgi/mysource_matrix/scripts/dev/checkout.sh?view=co
mv checkout.sh\?view\=co checkout.sh
sh checkout.sh $SQUIZ_MATRIX_VERSION

echo "Installing Markdown"
git clone https://github.com/ecenter/markdownify.git
cd markdownify/markdownify
mv markdownify.php /usr/bin
mv parsehtml /usr/bin
cd $PATH_TO_MATRIX
curl -O http://littoral.michelf.ca/code/php-markdown/php-markdown-1.0.1p.zip
unzip php-markdown-1.0.1p.zip
cd PHP\ Markdown\ 1.0.1p/
mv markdown.php /usr/bin

echo "Editing Database Config"
sed -i "s/local   all         postgres                          ident/local   all         postgres                          trust/g" /etc/postgresql/8.4/main/pg_hba.conf
sed -i "s/local   all         all                               ident/local   all         all                          trust/g" /etc/postgresql/8.4/main/pg_hba.conf

echo "Restart Postgres"
/etc/init.d/postgresql restart

echo "Create database users"
createuser -SRDU postgres matrix
createuser -SRDU postgres matrix_secondary
createdb -U postgres -O matrix -E UTF8 squiz_matrix
createlang -U postgres plpgsql squiz_matrix

echo "Initialize Squiz Matrix"
php $PATH_TO_MATRIX/squiz_matrix/install/step_01.php $PATH_TO_MATRIX/squiz_matrix

echo "Edit Squiz Matrix Configuration"
sed -i "s/define('SQ_CONF_SYSTEM_ROOT_URLS', '');/define('SQ_CONF_SYSTEM_ROOT_URLS', '$ROOT_URL');/g" $PATH_TO_MATRIX/squiz_matrix/data/private/conf/main.inc
sed -i "s/define('SQ_CONF_DEFAULT_EMAIL', '');/define('SQ_CONF_DEFAULT_EMAIL', '$DEFAULT_EMAIL');/g" $PATH_TO_MATRIX/squiz_matrix/data/private/conf/main.inc
sed -i "s/define('SQ_CONF_TECH_EMAIL', '');/define('SQ_CONF_TECH_EMAIL', '$DEFAULT_EMAIL');/g" $PATH_TO_MATRIX/squiz_matrix/data/private/conf/main.inc

echo "Edit db.inc file";
mv $PATH_TO_MATRIX/squiz_matrix/data/private/conf/db.inc $PATH_TO_MATRIX/squiz_matrix/data/private/conf/db-backup.inc
touch $PATH_TO_MATRIX/squiz_matrix/data/private/conf/db.inc
cat <<'EOF' >$PATH_TO_MATRIX/squiz_matrix/data/private/conf/db.inc
<?php
$db_conf = array (
       'db' => array (
          'DSN' => 'pgsql:dbname=squiz_matrix',
          'user' => 'matrix',
          'password' => '',
          'type' => 'pgsql',
          ),
       'db2' => array (
          'DSN' => 'pgsql:dbname=squiz_matrix',
          'user' => 'matrix',
          'password' => '',
          'type' => 'pgsql',
          ),
       'db3' => array (
          'DSN' => 'pgsql:dbname=squiz_matrix',
          'user' => 'matrix_secondary',
          'password' => '',
          'type' => 'pgsql',
          ),
       'dbcache' => NULL,
       'dbsearch' => NULL,
       );

return $db_conf;
?>
EOF

echo "Initialize Database"
php $PATH_TO_MATRIX/squiz_matrix/install/step_02.php $PATH_TO_MATRIX/squiz_matrix

echo "Initialize Core Asset Types"
php $PATH_TO_MATRIX/squiz_matrix/install/compile_locale.php $PATH_TO_MATRIX/squiz_matrix
php $PATH_TO_MATRIX/squiz_matrix/install/step_03.php $PATH_TO_MATRIX/squiz_matrix
php $PATH_TO_MATRIX/squiz_matrix/install/compile_locale.php $PATH_TO_MATRIX/squiz_matrix

echo "Fixing Permissions"
chmod -R 755 $PATH_TO_MATRIX/squiz_matrix
cd $PATH_TO_MATRIX/squiz_matrix
chown -R $APACHE_USER:$APACHE_USER data cache
chmod -R g+w data cache

echo "Updating Apache Virtual Hosts"
mv /etc/apache2/sites-enabled/000-default /etc/apache2/sites-enabled/000-default-backup
touch /etc/apache2/sites-enabled/000-default
cat <<EOF >/etc/apache2/sites-enabled/000-default
<VirtualHost *:80> 
ServerName $ROOT_URL 
DocumentRoot $PATH_TO_MATRIX/squiz_matrix/core/web 

Options -Indexes FollowSymLinks 

<Directory $PATH_TO_MATRIX/squiz_matrix> 
Order deny,allow 
Deny from all 
</Directory> 
<DirectoryMatch "^$PATH_TO_MATRIX/squiz_matrix/(core/(web|lib)|data/public|fudge)"> 
Order allow,deny 
Allow from all 
</DirectoryMatch> 
<DirectoryMatch "^$PATH_TO_MATRIX/squiz_matrix/data/public/assets"> 
php_flag engine off 
</DirectoryMatch> 

<FilesMatch "\.inc$"> 
Order allow,deny 
Deny from all 
</FilesMatch> 
<LocationMatch "/(CVS|\.FFV)/"> 
Order allow,deny 
Deny from all 
</LocationMatch> 

Alias /__fudge $PATH_TO_MATRIX/squiz_matrix/fudge 
Alias /__data $PATH_TO_MATRIX/squiz_matrix/data/public 
Alias /__lib $PATH_TO_MATRIX/squiz_matrix/core/lib 
Alias / $PATH_TO_MATRIX/squiz_matrix/core/web/index.php/ 
</VirtualHost>
EOF

echo "Restart Apache"
a2enmod rewrite
/etc/init.d/apache2 restart

echo "Adding Cron Jobs"
(crontab -l 2>/dev/null; echo "*/15 * * * * php $PATH_TO_MATRIX/squiz_matrix/core/cron/run.php\n0 0 * * * $PATH_TO_MATRIX/squiz_matrix/scripts/session_cleanup.sh $PATH_TO_MATRIX/squiz_matrix\n*/15 * * * * php $PATH_TO_MATRIX/squiz_matrix/packages/bulkmail/scripts/run.php") | crontab - -u $APACHE_USER

echo "############"
echo "Installation Finished!"
echo "############"
echo ""
echo "Login to Squiz Matrix using the following:"
echo "http://$ROOT_URL/_admin"
echo "Username: root"
echo "Password: root"
echo ""