apt-get update

echo "====== language location ========================"
apt-get install -y language-pack-ja ntp
sudo update-locale LANGUAGE=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 LANG=ja_JP.UTF-8
ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

echo "====== basic packeages ========================"
apt-get install -y openssh-server
systemctl restart ssh
apt-get install -y git curl libcurl4-openssl-dev wget build-essential g++ make
apt-get install -y zlib1g-dev libssl-dev libreadline-dev libyaml-dev libpq-dev libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev sqlite3 libsqlite3-dev nodejs imagemagick

echo "====== Apache passenger ========================"
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
echo "postfix postfix/mailname string vagrant.vm" | debconf-set-selections
apt-get install -y sysv-rc-conf apache2 apache2-dev libapache2-mod-evasive libapache2-mod-security2 passenger

echo "====== databases ========================"
echo "mysql-server mysql-server/root_password password ubuntu_user" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password ubuntu_user" | debconf-set-selections
apt-get install -y mysql-server mysql-client libmysqlclient-dev libmysqld-dev
apt-get install -y memcached redis-server
sed -i "s/.*bind-address/#bind-address /" /etc/mysql/mysql.conf.d/mysqld.cnf
mysql -u root --password='ubuntu_user' <<EOF
CREATE USER 'ubuntu_user'@'%' IDENTIFIED BY "ubuntu_user";
GRANT ALL PRIVILEGES ON *.* TO 'ubuntu_user'@'%' IDENTIFIED BY "ubuntu_user" with grant option;
FLUSH PRIVILEGES;
EOF
service mysql restart

echo "====== add user ========================"
useradd -m -p $(perl -e 'print crypt("ubuntu_user", "\$6\$saltsalt")') -s /bin/bash ubuntu_user
gpasswd -a ubuntu_user sudo

echo "====== ruby rails ========================"
cat >/home/ubuntu_user/startrails.sh << "EOF"
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git  ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
echo 'source ~/.bashrc' >> ~/.bash_profile
~/.rbenv/bin/rbenv install 2.4.2
~/.rbenv/bin/rbenv rehash
~/.rbenv/bin/rbenv global 2.4.2
~/.rbenv/bin/rbenv exec gem install bundler nokogiri rubocop --no-ri --no-rdoc
~/.rbenv/bin/rbenv exec gem install passenger --version 5.1.8 --no-ri --no-rdoc
~/.rbenv/bin/rbenv exec gem install rails -v 5.1.4 --no-ri --no-rdoc

sudo chown -R ubuntu_user:staff .rbenv/
echo "====== connect apache2-passenger ========================"
sudo cp /home/ubuntu_user/common_dir/apache2.conf /etc/apache2/apache2.conf
~/.rbenv/versions/2.4.2/bin/passenger-install-apache2-module --auto --languages=ruby

echo "====== setting apache2 ========================"
sudo gpasswd -a www-data ubuntu_user
sudo cp /home/ubuntu_user/common_dir/rails-ssl.conf /etc/apache2/sites-available
sudo a2dissite 000-default
sudo apache2ctl configtest
sudo a2ensite railsapp
sudo service apache2 reload

echo "====== auto ========================"
sysv-rc-conf apache2 on
exec $SHELL --login
EOF

echo "========aws cli goofys============"
cat >/home/ubuntu_user/aws-goofys.sh << "EOF"
wget https://redirector.gvt1.com/edgedl/go/go1.9.2.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.9.2.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version
[ ! -e ~/go/ ] && mkdir ~/go
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH="$PATH:$GOPATH/bin"' >> ~/.bashrc
/usr/local/go/bin/go get github.com/kahing/goofys
/usr/local/go/bin/go install github.com/kahing/goofys
/home/ubuntu_user/go/bin/goofys -h
sudo apt-get install awscli
aws --version
sudo mount -a
EOF
