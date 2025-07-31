# Arch Linux ARM 64-bit version for RPi4

This is a prebuilt version of [ArchLinuxARM](https://archlinuxarm.org/) 64-bit version (AArchv8) for Raspberry Pi 4 using [Github Action workflow file](https://github.com/vintheweirdass/archlinuxarm-rpi4-aarch64-prebuilt/actions/workflows/build-image.yml). 

I made this repository because I have a pain repartitioning and flashing the Arch Linux into sdcard from the VM (since I was on Windows) all over again
## Downloading

1. Download one of the Image with the `.zst` format from the [Releases](https://github.com/vintheweirdass/archlinuxarm-rpi4-aarch64-prebuilt) page.
   > The `.zst` ([Zstandard](https://github.com/facebook/zstd)) is very powerful since it compresses more than the normal `.zip` or `.gz` files
   >
   > Needs an [external program provided by Facebook](https://github.com/facebook/zstd/releases)

2. Unzip the file you have downloaded until the file extension is not `.zst`
3. Voilà! Now you can use the file (`.img`) to the [Raspberry Pi Imager](https://www.raspberrypi.com/software/)!
