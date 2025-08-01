          set -euxo pipefail
          
          # Generate timestamp
          TIMESTAMP=$(date +%Y-%m-%d)
          TIMESTAMP_IMG_NAME=$(date +%Y_%m_%d)
          IMG_NAME="archlinuxarm-rpi4-aarch64-${TIMESTAMP_IMG_NAME}-sdcard.img"
          
          # Create larger image (10GB instead of 8GB for safety)
          fallocate -l 10G "$IMG_NAME"
          
          # Create partition table with proper alignment and larger boot partition
          parted "$IMG_NAME" --script \
            mklabel msdos \
            mkpart primary fat32 2048s 1050623s \
            mkpart primary ext4 1050624s 100% \
            set 1 boot on
          
          # Setup loop device
          LOOP=$(sudo losetup --show -Pf "$IMG_NAME")
          echo "Using loop device: $LOOP"
          
          # Wait for partition devices to appear
          sleep 2
          
          # Format partitions with proper settings
          sudo mkfs.vfat -F 32 -n "BOOT" "${LOOP}p1"
          sudo mkfs.ext4 -F -L "ROOT" "${LOOP}p2"
          
          # Mount partitions
          mkdir -p boot rootfs
          sudo mount "${LOOP}p1" boot
          sudo mount "${LOOP}p2" rootfs
          
          # Download and verify rootfs with retries
          echo "Downloading Arch Linux ARM rootfs..."
          for i in {1..3}; do
            if wget -O rootfs.tar.gz http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz; then
              break
            fi
            echo "Download attempt $i failed, retrying..."
            sleep 5
          done
          
          # Verify download succeeded
          if [ ! -f rootfs.tar.gz ] || [ ! -s rootfs.tar.gz ]; then
            echo "Failed to download rootfs after 3 attempts"
            exit 1
          fi
          
          # Extract rootfs with proper permissions
          echo "Extracting rootfs..."
          sudo tar -xpf rootfs.tar.gz -C rootfs --numeric-owner
          
          # Move boot files to boot partition
          sudo mv rootfs/boot/* boot/ 2>/dev/null || true
          
          # Create proper fstab for RPi4 (uses mmcblk1 on some systems, mmcblk0 on others)
          sudo tee rootfs/etc/fstab > /dev/null << 'EOF'
# <file system>   <dir>   <type>  <options>         <dump>  <pass>
/dev/mmcblk1p2    /       ext4    defaults,noatime  0       1
/dev/mmcblk1p1    /boot   vfat    defaults          0       2
EOF
          
          # Add alternative fstab as backup
          sudo tee rootfs/etc/fstab.mmcblk0 > /dev/null << 'EOF'
# Alternative fstab for systems where SD shows as mmcblk0
/dev/mmcblk0p2    /       ext4    defaults,noatime  0       1
/dev/mmcblk0p1    /boot   vfat    defaults          0       2
EOF
          
          # Ensure proper permissions on boot files
          sudo find boot/ -type f -name "*.dtb" -exec chmod 644 {} \;
          sudo find boot/ -type f -name "*.dat" -exec chmod 644 {} \;
          sudo find boot/ -type f -name "*.elf" -exec chmod 644 {} \;
          sudo find boot/ -type f -name "kernel*" -exec chmod 644 {} \;
          
          # Create cmdline.txt if it doesn't exist
          if [ ! -f boot/cmdline.txt ]; then
            sudo tee boot/cmdline.txt > /dev/null << 'EOF'
root=/dev/mmcblk1p2 rw rootwait console=serial0,115200 console=tty1 selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 kgdboc=serial0,115200 elevator=noop
EOF
          fi
          
          # Create config.txt if it doesn't exist or modify existing one
          if [ ! -f boot/config.txt ]; then
            sudo tee boot/config.txt > /dev/null << 'EOF'
# Basic config for RPi4
arm_64bit=1
kernel=kernel8.img
disable_overscan=1

# GPU memory split
gpu_mem=64

# Enable UART
enable_uart=1

# HDMI settings
hdmi_force_hotplug=1

# USB power
max_usb_current=1

# Disable rainbow splash screen
disable_splash=1

# Enable I2C and SPI if needed
#dtparam=i2c_arm=on
#dtparam=spi=on

# Additional stability settings
over_voltage=2
arm_freq=1500
EOF
          else
            # Ensure essential settings are present
            sudo bash -c "
            if ! grep -q 'arm_64bit=1' boot/config.txt; then
              echo 'arm_64bit=1' >> boot/config.txt
            fi
            if ! grep -q 'enable_uart=1' boot/config.txt; then
              echo 'enable_uart=1' >> boot/config.txt
            fi
            if ! grep -q 'gpu_mem=' boot/config.txt; then
              echo 'gpu_mem=64' >> boot/config.txt
            fi
            "
          fi
          
          # Enable SSH by default (create ssh file in boot)
          sudo touch boot/ssh
          
          # Set up basic network configuration
          sudo mkdir -p rootfs/etc/systemd/network/
          sudo tee rootfs/etc/systemd/network/20-wired.network > /dev/null << 'EOF'
[Match]
Name=eth0

[Network]
DHCP=yes
EOF
          
          # Enable essential services
          sudo systemctl --root="$(pwd)/rootfs" enable systemd-networkd
          sudo systemctl --root="$(pwd)/rootfs" enable systemd-resolved
          sudo systemctl --root="$(pwd)/rootfs" enable sshd
          
          # Create a setup script for first boot
          sudo tee rootfs/root/first-boot-setup.sh > /dev/null << 'EOF'
#!/bin/bash
# First boot setup script for Arch Linux ARM on RPi4

# Check which SD card device is being used and fix fstab if needed
if [ -b /dev/mmcblk0 ] && ! [ -b /dev/mmcblk1 ]; then
    echo "Detected SD card as mmcblk0, updating fstab..."
    cp /etc/fstab.mmcblk0 /etc/fstab
fi

# Initialize pacman keyring
pacman-key --init
pacman-key --populate archlinuxarm

# Update system
pacman -Syu --noconfirm

# Install essential packages
pacman -S --noconfirm sudo vim nano wget curl

echo "First boot setup completed. You can delete this script."
EOF
          
          sudo chmod +x rootfs/root/first-boot-setup.sh
          
          # Create README for users
          sudo tee rootfs/root/README.txt > /dev/null << 'EOF'
Arch Linux ARM for Raspberry Pi 4 - AArch64

Default login:
Username: alarm
Password: alarm

Root login:
Username: root  
Password: root

Important:
1. Run /root/first-boot-setup.sh on first boot to complete setup
2. Change default passwords immediately
3. If boot fails, check /etc/fstab - you may need to use the alternative fstab.mmcblk0

To enable WiFi:
sudo wifi-menu

To update system:
sudo pacman -Syu
EOF
          
          # Final sync and cleanup
          sync
          sleep 2
          
          # Unmount filesystems
          sudo umount boot rootfs || true
          sudo losetup -d "$LOOP" || true
          
          # Create compressed versions
          echo "Creating compressed archives..."
          zstd -7 -k "$IMG_NAME"
          
          # Set output variables for artifact upload
          echo "IMG_NAME=${IMG_NAME}" >> $GITHUB_ENV
          echo "TIMESTAMP=${TIMESTAMP}" >> $GITHUB_ENV
          echo "TIMESTAMP_IMG_NAME=${TIMESTAMP_IMG_NAME}" >> $GITHUB_ENV
