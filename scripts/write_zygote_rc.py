content = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote
    setenv ANDROID_DATA /data
    setenv ANDROID_ROOT /system
    setenv ANDROID_RUNTIME_ROOT /apex/com.android.art
    setenv ANDROID_TZDATA_ROOT /apex/com.android.tzdata
    setenv ANDROID_IOTA_ROOT /apex/com.android.iota
    class main
    priority -20
    user root
    group root readproc reserved_disk
    socket zygote stream 660 root system
    socket usap_pool_primary stream 660 root system
    stdout /dev/kmsg
    stderr /dev/kmsg
    onrestart write /sys/android_power/request_state wake
    onrestart restart audioserver
    onrestart restart cameraserver
    onrestart restart media
    onrestart restart netd
    onrestart restart wificond

service system_server /system/bin/app_process64 /system/bin --nice-name=system_server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg

service zygote_secondary /system/bin/app_process32 -Xzygote /system/bin --zygote --socket-name=zygote_secondary --enable-lazy-preload
    class main
    priority -20
    user root
    group root readproc reserved_disk
    socket zygote_secondary stream 660 root system
    socket usap_pool_secondary stream 660 root system
    onrestart restart zygote
    stdout /dev/kmsg
    stderr /dev/kmsg
'''

with open('/root/harmony-build/initramfs-boot/init.zygote64_32.rc', 'w') as f:
    f.write(content)

print("init.zygote64_32.rc updated successfully")
