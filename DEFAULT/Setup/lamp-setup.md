💻 Full LAMP + Project Setup in Zorin OS (XAMPP Alternative)
STEP 0 — Old XAMPP Remove (Optional but Recommended)
sudo /opt/lampp/uninstall
sudo rm -rf /opt/lampp
sudo rm -rf /usr/bin/php

STEP 1 — Update System & Install Apache
sudo apt update
sudo apt install apache2 -y
sudo systemctl start apache2
sudo systemctl enable apache2


Check Apache:

http://localhost

STEP 2 — Install PHP (CLI + Apache module) with common extensions
sudo apt install php8.3 php8.3-cli libapache2-mod-php8.3 \
php8.3-mbstring php8.3-xml php8.3-zip php8.3-curl php8.3-gd php8.3-mysql php8.3-bcmath -y


Set PHP CLI:

sudo update-alternatives --set php /usr/bin/php8.3


Check:

php -v


Restart Apache:

sudo systemctl restart apache2

STEP 3 — Install MariaDB (MySQL Alternative)
sudo apt install mariadb-server -y


Login to MariaDB:

sudo mysql


Set empty password (optional):

ALTER USER 'root'@'localhost' IDENTIFIED BY '';
FLUSH PRIVILEGES;
EXIT;

STEP 4 — Install phpMyAdmin
sudo apt install phpmyadmin -y


During install:

Select Apache2

Yes → configure database

Set password (optional)

Enable PHP modules:

sudo phpenmod mbstring
sudo phpenmod mysqli
sudo phpenmod gettext
sudo systemctl restart apache2


Fix /phpmyadmin access:

sudo ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin


Allow empty password (optional):

# Edit /etc/phpmyadmin/config.inc.php
$cfg['Servers'][$i]['AllowNoPassword'] = true;


Check:

http://localhost/phpmyadmin

STEP 5 — Create Project Folder

Option 1 — /var/www/html (simple):

sudo mkdir -p /var/www/html/project1
sudo chown -R $USER:$USER /var/www/html/project1
sudo chmod -R 755 /var/www/html/project1


Option 2 — Custom folder in Home (recommended):

mkdir -p /home/shagor/Projects/project1
sudo chown -R $USER:$USER /home/shagor/Projects/project1
sudo chmod -R 755 /home/shagor/Projects/project1

STEP 6 — Setup Apache Virtual Host

Create config:

sudo nano /etc/apache2/sites-available/project1.conf


Paste:

<VirtualHost *:80>
    ServerName project1.test
    DocumentRoot /home/shagor/Projects/project1/public

    <Directory /home/shagor/Projects/project1/public>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>


Enable VirtualHost:

sudo a2ensite project1.conf
sudo systemctl reload apache2


Add hosts entry:

sudo nano /etc/hosts


Add line:

127.0.0.1   project1.test


Check in browser:

http://project1.test

STEP 7 — Enable Apache Rewrite (for Laravel routing)
sudo a2enmod rewrite
sudo systemctl restart apache2

STEP 8 — PHP Extensions for Laravel (if not installed)
sudo apt install php8.3-mbstring php8.3-xml php8.3-curl php8.3-zip php8.3-bcmath php8.3-gd php8.3-mysql -y
sudo systemctl restart apache2


যদি system reboot এর পরে Apache বা MariaDB না চলে, তবে:

sudo systemctl start apache2
sudo systemctl start mariadb
