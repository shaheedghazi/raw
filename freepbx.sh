#!/bin/bash -e

LOG_FILE="/var/log/freepbx_install.log"

# Redirect all output to log file
exec &> >(tee -a "$LOG_FILE")

# Function to log messages
log() {
    echo "$(date +"%Y-%m-%d %T"): $*"
}

log "Starting FreePBX VoIP Server installation..."

# Add swap file
log "Adding swap file..."
dd if=/dev/zero of=/1GB.swap bs=1024 count=1048576
mkswap /1GB.swap
chmod 0600 /1GB.swap
swapon /1GB.swap
echo "/1GB.swap  none  swap  sw 0  0" >> /etc/fstab
echo "vm.swappiness=10" >> /etc/sysctl.conf

# Update system and install required packages
log "Updating system and installing required packages..."
yum -y update
yum -y groupinstall core base "Development Tools"
yum -y remove firewalld
yum -y install lynx tftp-server unixODBC mysql-connector-odbc mariadb-server mariadb httpd ncurses-devel sendmail sendmail-cf sox newt-devel libxml2-devel libtiff-devel audiofile-devel gtk2-devel subversion kernel-devel git crontabs cronie cronie-anacron wget vim uuid-devel sqlite-devel net-tools gnutls-devel python-devel texinfo libuuid-devel

# Install additional repositories and packages
log "Installing additional repositories and packages..."
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
yum -y install php56w php56w-pdo php56w-mysql php56w-mbstring php56w-pear php56w-process php56w-xml php56w-opcache php56w-ldap php56w-intl php56w-soap
curl -sL https://rpm.nodesource.com/setup_8.x | bash -
yum -y install nodejs

# Enable and start MariaDB
log "Enabling and starting MariaDB..."
systemctl enable mariadb.service
systemctl start mariadb

# Secure MariaDB installation
log "Securing MariaDB installation..."
mysql_secure_installation <<EOF
y
n
y
y
y
EOF

# Enable and start Apache
log "Enabling and starting Apache..."
systemctl enable httpd.service
systemctl start httpd.service

# Download and install Asterisk and dependencies
log "Downloading and installing Asterisk and dependencies..."
pushd /usr/src
wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/libpri/libpri-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-14-current.tar.gz
wget -O jansson.tar.gz https://github.com/akheron/jansson/archive/v2.10.tar.gz
popd

pushd /usr/src
tar vxfz jansson.tar.gz
rm -f jansson.tar.gz
pushd jansson-*
autoreconf -i
./configure --libdir=/usr/lib64
make
make install
popd

tar xvfz asterisk-14-current.tar.gz
rm -f asterisk-14-current.tar.gz
pushd asterisk-*
contrib/scripts/install_prereq install
./configure --libdir=/usr/lib64 --with-pjproject-bundled
contrib/scripts/get_mp3_source.sh
make menuselect
# INTERACTIVE: select format_mp3 on first page, save and exit

make
make install
make config
ldconfig
chkconfig asterisk off
chown asterisk. /var/run/asterisk
chown -R asterisk. /etc/asterisk
chown -R asterisk. /var/{lib,log,spool}/asterisk
chown -R asterisk. /usr/lib64/asterisk
chown -R asterisk. /var/www/
popd

# Configure PHP settings
log "Configuring PHP settings..."
sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php.ini

# Configure Apache settings
log "Configuring Apache settings..."
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/httpd/conf/httpd.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
systemctl restart httpd.service

# Download and install FreePBX
log "Downloading and installing FreePBX..."
wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-14.0-latest.tgz
tar xfz freepbx-14.0-latest.tgz
rm -f freepbx-14.0-latest.tgz
pushd freepbx
./start_asterisk start
./install -n
popd

# Configure systemd service for FreePBX
log "Configuring systemd service for FreePBX..."
echo "[Unit]
Description=FreePBX VoIP Server
After=mariadb.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/fwconsole start -q
ExecStop=/usr/sbin/fwconsole stop -q
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/freepbx.service
systemctl enable freepbx.service

# Display server IP
log "Server IP: $(curl http://169.254.169.254/latest/meta-data/public-ipv4 --silent)"

log "Installation completed successfully."
