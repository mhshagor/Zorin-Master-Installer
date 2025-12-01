১) Full Permission (read, write, execute)
sudo chmod -R 777 /opt


৩) Owner change করা (root → user)

যদি permission error পান, সাধারণত owner change করলেই ঠিক হয়ে যায়:

sudo chown -R $USER:$USER /path/to/folder