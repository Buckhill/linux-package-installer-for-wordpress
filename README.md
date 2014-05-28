###Linux Package Installer for Wordpress (LPI-WP) 

LPI-WP installs and auto configures Wordpress, with by default, **ssh-sftp-updater** and **w3-total-cache** modules.  Additional default modules can be specified.

LPI-WP is primarily designed to work with Web Chroot Manager (WCM) (https://github.com/Buckhill/web-chroot-manager), but with extra parameters provided it can function independently on any generic LAMP installation.

#### Limitations

LPI-WP has been designed for Ubuntu 12.04+ LTS.  Debian is not yet officially support but should work. CentOS/Redhat support are due with the next release.

It is assumed MySQL is listening on 127.0.0.1:3306

#### Installation requirements

The domain which will be configured using LPI-WP must be resolvable by the server

#### How to use LPI-WP

There are two modes, WCM mode (default) and generic mode

WCM can be found here: https://github.com/Buckhill/web-chroot-manager

Usage: ./linux-package-installer-for-wordpress.sh [options...]

#### WCM mode

LPI-WP relies on WCM configuration files. This mode is default, only two options are required:

- -u (Secondary Username)
- -s (Domain Name)

After Wordpress has successfully installed the script outputs the credentials for the WP admin user

**Optional arguments:**

- -c path to WCM config dir. /etc/buckhill-wcm is default

#### Generic mode

Can be ran on any LAMP installation, WCM is not required.  It is assumed the MySQL server is running locally

**Certain parameters are mandatory:**

- -g enables generic mode
- -w web user. The user under PHP scripts are ran. On Ubuntu this is 'www-data'
- -d full path of a directory where Wordpress will be installed
- -u User which will be the owner of the Wordpress files. Can be the same as web user, but not recommended. Can be root.
- -e email address. Needed for Wordpress installation, otherwise final configuration will fail

**Optional arguments:**

- -m Database name. LPI-WP will by default automatically generate the DB name and DB user from the username and site name given.  This can be overwritten by using this option
- -y Answer "y" to all questions
- -t path to temporary folder where Wordpress and modules are downloaded. Default is /tmp/wp_install
