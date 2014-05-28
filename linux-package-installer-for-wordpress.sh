#!/bin/bash

#Author: Marko Bencek
#email: marko@buckhill.co.uk
#Date 04/17/2014
#Copyright Buckhill Ltd 2014
#Website www.buckhill.co.uk
#GitHub: https://github.com/Buckhill/linux-package-installer-for-wordpress
#License GPLv3

CFGDIR=/etc/buckhill-wcm

[ "$(whoami)" != "root" ] && { echo "Please run me as root";exit 1;}

#!! Everyting older than 10 days will be deleted from TEMPDIR
TMPDIR=/tmp/wp_install
DB_SERVER=127.0.0.1

function usage
{
	cat <<END
Usage: $0  [options]
 -g		Script by default uses Buckhill WCM (Web-chroot-manager) configuration files. 
		Option enables generic mode where script works standalone.  
		Extra options are mandatory in this mode.
 -w		Specify web server user. Usually www-data. Option is 
		mandatory in generic mode, otherwise ignored.
 -d		Site's document root. Option is mandatory in generic mode,
		otherwise ignored. Content in directory might be overwritten.
 -s		Domain name. Has to be resolvable. Option is mandatory.
 -u		Username under which Wordpress will be installed. In 
		Buckhill WCM mode secondary account has to be specified.
		Option is mandatory.
 -m		Database name. If not provided, generated automaticaly.
 -e   Email address. Mandatory in generic mode.
 -c		Path to Buckhill WCM configuration dir. Default is 
		/etc/buckhill-wcm
 -y		Answer "y" to all questions.
 -t		Temporary directory. Used for download Wordpress and modules.
		Default is /tmp/wp_install
 -h		This help.
END

	if [ "$1" == "ok" ]
	then
		exit 0
	else
		exit 1
	fi
}

function mysql_check
{
	if [ -z "$1" ] 
	then 
		if  mysql -u root -h $DB_SERVER -e "show databases" >/dev/null  2>&1
		then
			return 0
		else
			return 1
		fi
	else
		if mysql -u root -h $DB_SERVER -p"$1" -e "show databases" >/dev/null  2>&1
		then
			return 0
		else
			return 1
		fi
	fi 
}

function dbn_sanity_check
{
        if echo "$1" |grep -q '^[a-zA-Z0-9_]\+$'
        then
                return 0
        else
                return 1
        fi
}


function login_sanity_check
{
        if echo "$1" |grep -q '^[a-z][a-z0-9_\-]\{1,14\}[^\-]$'
        then
                return 0
        else
                
                return 1
        fi
}
 
function user_exists_check
{
        if grep -q "^$1:" /etc/passwd
        then
                return 0
        else
                return 1
        fi      
}

function gid 
{
	awk -v user=$1 -F : '$1 == user {print $4}' /etc/passwd
}


function error_stop
{

	echo $*
	exit 1
}

function ask_y
{
	[ "$1" == "y" ] && return 0 

	read y 
	if [ "$y" == "y" ] || [ "$y" == "Y" ] 
	then
		return 0
	else
		return 1
	fi
}


function download
{
	TMPAGE=10
	if find $TMPDIR/${1##*/} -mtime +$TMPAGE |grep -q ${1##*/} 
	then
		echo "The $TMPDIR/${1##*/} is older then $TMPAGE days."
		echo "Shell I delete it and download again (y) ?"
		if ask_y $YES
		then
			rm -f $TMPDIR/${1##*/}
		fi
	fi
	if [ ! -f $TMPDIR/${1##*/} ]
	then
        	echo "Downloading ${1##*/}."
        	wget -O $TMPDIR/${1##*/} -o /dev/null $1
		touch $TMPDIR/${1##*/}
	fi
}

[ -z "$4" ]  && usage

while getopts ":u:d:c:t:hgys:w:m:e:" o
do
        case "$o" in
                g)
                        GENERIC=1
                        ;;
                u)
                       	USER=${OPTARG} 
                        ;;
		w)
			WEBUSER=${OPTARG}
			;;
                s)
                        SITE=${OPTARG}
                        ;;
                d)
                        SITEDIR=${OPTARG}
                        ;;
		t)
			TMPDIR=${OPTARG}
			;;
		m)
			DBNAME=${OPTARG}
			;;
		e)	
			EMAILO=${OPTARG}
			;;
		c)
			if [ -z "${OPTARG}" ] 
			then
				usage
			else
				CFGDIR=${OPTARG}
			fi
			;;
		y)
			YES=y
			;;
		h)
			usage ok
			;;
		*)
			usage
			;;
        esac
done
shift $((OPTIND-1))
#Minimal parameters check
if [ "$GENERIC" == "1" ]
then
	[ -n "$USER" ]  ||  error_stop "User is not specified."
	[ -n "$SITE" ] ||  error_stop "Site URL is not specified"
	[ -n "$SITEDIR" ] || error_stop "Site's dir is not specified."
 	[ -n "$WEBUSER" ] || error_stop "Web user is not specified"
	[ -n "EMAILO" ] || error_stop "Email is not specified"
	
else
	[ -n "$SITE" ] || usage
	[ -n "$USER" ] || usage

	#BH LPI profile
	[ -d $CFGDIR ] || error_stop "Buchkhill LPI config dir is missing. Use -c or -g switches" 
	if [ -f $CFGDIR/general.conf ] 
	then
		. $CFGDIR/general.conf
		[ -n "$WebDir" ] || error_stop "The WebDir is not specified in general.conf" 
	else 
		 error_stop  "Buchkhill LPI general.conf is missing in $CFGDIR" 
	fi

	if [ -f $CFGDIR/sites/$SITE.conf ]
	then
        	. $CFGDIR/sites/$SITE.conf
		if [ -n "$PARENT" ]
		then
			WEBUSER=$PARENT
		else 
			error_stop "The PARENT is not specified in Buckhill LPI configuration."
		fi
	else
       		 error_stop "Configuration file for $SITE doesn't exist"
	fi

	if [ -f $CFGDIR/accounts/$USER/user.conf ]
	then
        	. $CFGDIR/accounts/$USER/user.conf
        	[ -z "$OBJECT_TYPE" ] || [ "$OBJECT_TYPE" != "secondary" ] && error_stop "Account has to be secondary"
	else
        	error_stop "Error: Configuration file for $USER doesn't exist"
	fi

	[ -z "$SITEDIR" ] && SITEDIR="$WebDir/$SITE/htdocs"
fi

[ -n "$EMAILO" ] && EMAIL=$EMAILO


#dependencies check
Dependencies="curl unzip"
for  Dependency in $Dependencies
do
	which $Dependency |grep -qi $Dependency  || {
		echo "The $Dependency is missing"
		exit 1
		}
done 

#Parameters validation
#USER
if  user_exists_check $USER
then
	USER_GID=`gid $USER`
else
	error_stop "User $USER doesn't exist"
fi

#WEB user
if  user_exists_check $WEBUSER
then
	WEB_GID=`gid $WEBUSER`
else
	error_stop "User $WEBUSER doesn't exist"
fi

if [ -d $SITEDIR ] 
then
 	if find $SITEDIR  -maxdepth 0 -empty |grep -q $SITEDIR 
	then
		:
	else
		echo "The $SITEDIR is not empty."
		ls -al $SITEDIR |awk '{print $9}'
		echo " "
		echo "Some of these files might be overwritten. Continue? ( y ): "
		ask_y $YES || exit 1
	fi
else
	error_stop "The $SITEDIR doesn't exist"
fi	

#checking Site url
until [ -n "$TMPFILE" ] && [ ! -f $SITEDIR/$TMPFILE ]
do
	TMPFILE="$(cat /dev/urandom | tr -cd "[:alnum:]" | head -c 8).html"
	sleep 1 
done

touch $SITEDIR/$TMPFILE
WGET_OUT=`wget -O /dev/null $SITE/$TMPFILE 2>&1`

if echo "$WGET_OUT" |grep -q "200 OK" 
then
	rm -f $SITEDIR/$TMPFILE
else
	echo "Site is not responding as expected"
	echo "$WGET_OUT"
	exit 1
fi

MY_PASS=''
until mysql_check $MY_PASS
do
	read -p "Insert mysql root password: " MY_PASS
done 
[ -n "$MY_PASS" ]  && MYOPTIONS="-p$MY_PASS"

if [ -z "$DBNAME" ]
then
	if [ "$GENERIC" == "1" ]
	then	 
		dbn=$(echo "wp_$SITE" |sed 's/\./_/g'|head -c 16)
	else
		dbn=$(echo "${WEBUSER}_$SITE" |sed 's/\./_/g'|head -c 16)
	fi
else
	dbn_sanity_check $DBNAME || error_stop "Illegal character found in database name."
	[ ${#DBNAME} -gt 16 ] && error_stop "Database name is to long."
	dbn=$DBNAME
fi

mysql -e "show databases;" |awk '{print $1}' |grep -q "^$dbn$" && error_stop "Database $dbn already exists"

[ -d $TMPDIR ] || mkdir -p $TMPDIR

for download in http://wordpress.org/latest.tar.gz http://downloads.wordpress.org/plugin/ssh-sftp-updater-support.zip http://downloads.wordpress.org/plugin/w3-total-cache.zip http://downloads.wordpress.org/plugin/wordfence.zip
do
	download $download
done

cd $TMPDIR

for download in http://wordpress.org/latest.tar.gz http://downloads.wordpress.org/plugin/ssh-sftp-updater-support.zip http://downloads.wordpress.org/plugin/w3-total-cache.zip http://downloads.wordpress.org/plugin/wordfence.zip
do
	[ -f $TMPDIR/${download##*/} ] || error_stop "The ${download##*/} is missing" 
done

echo "Installing Wordress" 
tar -xzf latest.tar.gz
cd wordpress 
mv * $SITEDIR
rmdir $TMPDIR/wordpress
cd $SITEDIR/wp-content/plugins
echo "Installing ssh-sftp-updater module" 
unzip -qq $TMPDIR/ssh-sftp-updater-support.zip
echo "Installing w3-total-cache module"
unzip -qq $TMPDIR/w3-total-cache.zip
mkdir $SITEDIR/wp-content/cache $SITEDIR/wp-content/w3tc-config
echo "Installing wordfence module"
unzip -qq $TMPDIR/wordfence.zip
cd $SITEDIR

echo Creating database $dbn
dbp=`cat /dev/urandom | tr -cd "[:alnum:]" | head -c 8`
mysql $MYOPTIONS -e "create database $dbn;"
mysql $MYOPTIONS -e "grant all on $dbn.* to $dbn@localhost identified by \"$dbp\";";

sed -e "s/database_name_here/$dbn/" -e "s/username_here/$dbn/" -e "s/password_here/$dbp/" -e "s/localhost/127.0.0.1/" wp-config-sample.php > wp-config.php

#temporary permissions 
mkdir $SITEDIR/wp-content/uploads
chown -R $USER:$USER_GID  $SITEDIR

wpp=`cat /dev/urandom | tr -cd "[:alnum:]" | head -c 8`

curl -X 'POST' -H "Referer: http://$SITE/wp-admin/install.php" --form-string "weblog_title=$SITE" --form-string 'user_name=admin' --form-string "admin_password=$wpp" --form-string "admin_password2=$wpp" --form-string "admin_email=$EMAIL" --form-string 'blog_public=1' --form-string 'Submit=Install WordPress' "http://$SITE/wp-admin/install.php?step=2"  >/dev/null 2>/dev/null

for i in ssh-sftp-updater-support/sftp.php w3-total-cache/w3-total-cache.php wordfence/wordfence.php
do
	echo "Activating $i"
cat <<END | sudo -u $USER php
<?php
@include "wp-config.php";
@include_once "wp-includes/functions.php";
@include_once "wp-admin/includes/plugin.php";

if (!defined('DB_NAME'))
	die("ERROR: DB_NAME not defined. Are you in the 'wordpress' directory?\n");

activate_plugin("$i", '', /* network wide? */ false, /* silent? */ false);

END

done
#wp-cache
echo "define('WP_CACHE', true); // Added by W3 Total Cache" >> $SITEDIR/wp-config.php
cat >>$SITEDIR/.htaccess << END
# BEGIN W3TC Browser Cache
<IfModule mod_deflate.c>
    <IfModule mod_headers.c>
        Header append Vary User-Agent env=!dont-vary
    </IfModule>
        AddOutputFilterByType DEFLATE text/css text/x-component application/x-javascript application/javascript text/javascript text/x-js text/html text/richtext image/svg+xml text/plain text/xsd text/xsl text/xml image/x-icon application/json
    <IfModule mod_mime.c>
        # DEFLATE by extension
        AddOutputFilter DEFLATE js css htm html xml
    </IfModule>
</IfModule>
# END W3TC Browser Cache

END

#final permissions
chown -R $USER:$USER_GID  $SITEDIR
chmod -R g-w $SITEDIR
chown -R $USER:$WEBUSER_GID $SITEDIR/wp-content/uploads
chmod -R g+w  $SITEDIR/wp-content/uploads
chown -R $USER:$WEBUSER_GID $SITEDIR/wp-content/cache
chmod g+w $SITEDIR/wp-content/cache
chown -R $USER:$WEBUSER_GID $SITEDIR/wp-content/w3tc-config
chmod g+w $SITEDIR/wp-content/w3tc-config

[ -d $SITEDIR/wp-content/cache/config ] && rm -rf $SITEDIR/wp-content/cache/config
[ -d $SITEDIR/wp-content/cache/tmp ] && rm -rf $SITEDIR/wp-content/cache/tmp

echo -e "WP Username: admin\nWP Passwd: $wpp"
