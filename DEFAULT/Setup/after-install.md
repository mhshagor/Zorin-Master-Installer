📌 ZRAM + Disk Swap Full Optimized Setup (For 8GB RAM)
1️⃣ Install ZRAM tools (if not installed)
sudo apt install zram-tools

2️⃣ Edit ZRAM config file
sudo nano /etc/default/zram-config

inside add/set:

ALGO=zstd
PERCENT=40
PRIORITY=100


Save → CTRL+S → Exit → CTRL+X

3️⃣ Restart ZRAM service
sudo systemctl restart zram-config.service

(some systems use: sudo systemctl restart systemd-zram-setup)

4️⃣ Create fallback disk swap (recommended for heavy users)
sudo swapoff -a
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab

This creates 2GB fallback swap.

5️⃣ Optimize Linux swappiness (so swap is used only when needed)
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

6️⃣ Verify Status
swapon --show
free -h


Expected output example:

NAME        TYPE       SIZE  USED  PRIO
/dev/zram0  partition  3.1G   0B   100
/swapfile   file       2.0G   0B   -2

7️⃣ Optional: Check compression algorithm
cat /sys/block/zram0/comp_algorithm

Should show zstd active.

🎯 Result Summary
Component	Status	Benefit
40% ZRAM (≈ 3.2GB)	✔	Fast swap, high performance
2GB Disk Swap	✔	No freeze / crash under heavy load
Low swappiness (10)	✔	RAM uses priority first
ZSTD compression	✔	Best balance of speed + compression
🚀 Final System Benefits

Faster multitasking

Zero freeze during heavy workload

Better performance with Chrome, VS Code, Laravel, Android Studio

SSD wear reduced

Best optimized hybrid RAM management

Done 👍

তুমি এখন Linux-এ pro-level memory optimization করে ফেলেছো।
