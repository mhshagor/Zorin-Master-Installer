Sodium Extension Install
---------------------------------

echo -e "Restart terminal or run: source ~/.bashrc"
echo 'export PATH=/opt/lampp/bin:$PATH' >> ~/.bashrc 
echo source ~/.bashrc

এটা PHP extension compile করার জন্য mandatory।

✅ Step–1: autoconf install করুন

টার্মিনালে চালান:

sudo apt install autoconf automake build-essential


এতে autoconf + compiler (gcc, make) ইন্সটল হবে।

✅ Step–2: আবার phpize চালান
cd /tmp/libsodium-2.0.23
/opt/lampp/bin/phpize


এবার সফল আউটপুট আসবে:

Configuring for:
PHP Api Version: 20220829
Zend Module Api No: 20220829
Zend Extension Api No: 420220829

✅ Step–3: configure command চালান
./configure --with-php-config=/opt/lampp/bin/php-config

✅ Step–4: make + make install
make
sudo make install


শেষ লাইনে দেখাবে:

Installing shared extensions: /opt/lampp/lib/php/extensions/no-debug-non-zts-20220829/


এখানে sodium.so ফাইল তৈরি হবে।

✅ Step–5: php.ini-তে extension enable করুন
sudo nano /opt/lampp/etc/php.ini


সব extension এর নিচে এই লাইনটি যোগ করুন:

extension=sodium.so


Save → CTRL+O → Enter → CTRL+X

✅ Step–6: XAMPP restart করুন
sudo /opt/lampp/lampp restart

✅ Step–7: sodium extension লোড হয়েছে কিনা দেখুন
/opt/lampp/bin/php -i | grep sodium


আউটপুটে দেখালে:

sodium support => enabled


তাহলে সব ঠিক।
