# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=Custom Kernel by @ChuckDXD on Telegram
do.devicecheck=1
do.modules=1
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=olivelite
device.name2=olivewood
device.name3=olive
device.name4=olives
device.name5=pine
supported.versions=
'; } # end properties

# shell variables
block=/dev/block/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel install
split_boot;
flash_boot;
flash_dtbo;

ui_print " "

ui_print "Mounting /vendor and /system..."
mount -o rw,remount /vendor
mount -o rw,remount /system

# Patch WiFI HAL
ui_print "Detecting WiFI HAL..."
wifi_hal=$(find /vendor/lib64 /vendor/lib -name "libwifi-hal.so" | head -n 1)
if grep -q "pronto_wlan.ko" $wifi_hal; then
    ui_print "Patching WiFI HAL..."
    func_hex_offset=$(./tools/readelf $wifi_hal -sW | grep "is_wifi_driver_loaded" | awk '{print $2}')
    func_dec_offset=$(printf "%d" "0x"$func_hex_offset)
    hal_arch=$(./tools/readelf -h $wifi_hal | grep "Class" | awk '{print $2}')
    if [ $hal_arch == "ELF64" ]; then
        # patch:
        #   mov w0, #0x1
        #   ret
        printf '\x20\x00\x80\x52\xc0\x03\x5f\xd6' | ./tools/busybox dd of=$wifi_hal bs=1 seek=$func_dec_offset conv=notrunc status=none
    else
        # patch:
        #   mov r0, #0x1
        #   mov pc, lr
        # We must substract 1 to function address because of Thumb's least-significant bit
        printf '\x01\x20\xf7\x46' | ./tools/busybox dd of=$wifi_hal bs=1 seek=$[$func_dec_offset-1] conv=notrunc status=none
    fi
    # Give WiFi HAL fwpath sysfs privileges
    ui_print "Patching vendor's init..."
    insert_line /vendor/etc/init/hw/init.qcom.rc "chown wifi wifi /sys/module/wlan/parameters/fwpath" after "    chmod 0660 /sys/kernel/dload/dload_mode" $(printf "\n    chown wifi wifi /sys/module/wlan/parameters/fwpath")
else
    ui_print "No WiFi HAL patching needed."
fi

## end install

