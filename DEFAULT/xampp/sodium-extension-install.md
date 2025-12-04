# Sodium Extension Installation Guide
https://stackoverflow.com/questions/78765759/add-extension-in-ubuntu-2204-to-xampp
## Overview
This guide provides step-by-step instructions for compiling and installing the Sodium PHP extension, which is mandatory for certain PHP applications.

## Prerequisites
- XAMPP installed on your system
- Terminal access with sudo privileges
- Internet connection for downloading packages

---

## ✅ Step 1: Install autoconf and build tools

Install the required compilation tools:

```bash
sudo apt install autoconf automake build-essential
```

This will install:
- autoconf
- automake  
- gcc compiler
- make utility
- Other essential build tools

---

## ✅ Step 2: Run phpize

Navigate to the libsodium source directory and prepare for compilation:

```bash
cd /tmp/libsodium-2.0.23
/opt/lampp/bin/phpize
```

**Expected successful output:**
```
Configuring for:
PHP Api Version: 20220829
Zend Module Api No: 20220829
Zend Extension Api No: 420220829
```

---

## ✅ Step 3: Configure the build

Run the configure script with the correct PHP configuration path:

```bash
./configure --with-php-config=/opt/lampp/bin/php-config
```

---

## ✅ Step 4: Compile and install

Build and install the extension:

```bash
make
sudo make install
```

**Expected final output:**
```
Installing shared extensions: /opt/lampp/lib/php/extensions/no-debug-non-zts-20220829/
```

The `sodium.so` file will be created in this directory.

---

## ✅ Step 5: Enable the extension in php.ini

Edit the PHP configuration file:

```bash
sudo nano /opt/lampp/etc/php.ini
```

Add this line at the end of the extensions section:

```ini
extension=sodium.so
```

Save the file:
- Press `CTRL+O` to save
- Press `Enter` to confirm
- Press `CTRL+X` to exit

---

## ✅ Step 6: Restart XAMPP

Restart all XAMPP services to load the new extension:

```bash
sudo /opt/lampp/lampp restart
```

---

## ✅ Step 7: Verify installation

Check if the Sodium extension is loaded successfully:

```bash
/opt/lampp/bin/php -i | grep sodium
```

**Expected output:**
```
sodium support => enabled
```

If you see this output, the Sodium extension has been successfully installed and is ready to use.

---

## Troubleshooting

### Common Issues

1. **Permission denied errors**
   - Ensure you're using `sudo` for commands that require root privileges
   - Check that you have proper permissions on the XAMPP directories

2. **phpize command not found**
   - Verify XAMPP is properly installed
   - Check that `/opt/lampp/bin/phpize` exists and is executable

3. **Compilation errors**
   - Ensure all build tools are installed (Step 1)
   - Check that you have sufficient disk space
   - Verify the libsodium source files are complete

4. **Extension not loading**
   - Double-check the php.ini file path
   - Ensure the extension line is properly formatted
   - Verify the sodium.so file exists in the extensions directory

### Verification Commands

To get more detailed information about the Sodium extension:

```bash
# Check PHP version and API
/opt/lampp/bin/php -v

# List all loaded extensions
/opt/lampp/bin/php -m | grep sodium

# Get detailed PHP info
/opt/lampp/bin/php -i | grep -A 10 "sodium"
```

---

## Next Steps

After successful installation:
- Test your PHP applications that require Sodium
- Verify cryptographic functions are working properly
- Consider updating your application documentation to reflect the new capability

---

**Note:** This installation is specifically for XAMPP on Linux systems. Adjust paths accordingly for different operating systems or XAMPP installations.
