# Arch Linux ARM 64-bit version for RPi4

This is a prebuilt version of [ArchLinuxARM](https://archlinuxarm.org/) 64-bit version (AArchv8) for Raspberry Pi 4. 

I made this repository because I have a pain repartitioning and flashing the sdcard from the VM (since I was on Windows) all over again

## Downloading

1. Download one of the Image (that contains `sdcard.img` on the compressed files) from the [Releases](https://github.com/vintheweirdass/archlinuxarm-rpi4-aarch64-prebuilt) page.
   > The `.zst` ([Zstandard](https://github.com/facebook/zstd)) version only for more-compressed version.
   > Useful if your internet isn't strong enough to download the raw image or the normal compressed version. 
   >
   > Needs an [external program provided by Facebook](https://github.com/facebook/zstd/releases)
   >
   > The `.zip` and `.gz` are the normal compressed version.
   >
   > Natively, Windows can only extract `.zip`. While on Linux you can only extract `.gz`.
   > Both can extract other unsupported compressed files using external app

2. Unzip the file you have downloaded until the file format is not `.zip`, `.gz`, `.zst`, or other compressed format

3. Voilà! Now you can use the file (`.img`) to the [Raspberry Pi Imager](https://www.raspberrypi.com/software/)!
