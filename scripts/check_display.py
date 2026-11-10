with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    count = 0
    for line in f:
        if any(kw in line.lower() for kw in ['dri', 'virtio-gpu', 'drm', 'framebuffer', 'fb0', 'display', 'egl', 'gles', 'surfaceflinger:']):
            print(line.rstrip())
            count += 1
            if count >= 40:
                break