/* dltrace.c -- app_process64/arkinit'in dlopen ve
 * android_dlopen_ext cagrilarini gorunur kilar.
 *
 * SORUN (olculdu, arac iki bagimsiz testte dogrulandi):
 *   app_process64 libart.so'yu HIC yuklemiyor; 8 zaman noktasinda
 *   libart=0. 190 kutuphane yukluyor ama ICINDE HICBIR VM KUTUPHANESI
 *   yok. dltrace ile: 10 dlopen cagri, 0 basarisiz, hicbiri libart
 *   icin, android_dlopen_ext HIC cagrilmadi.
 *   => Bu ikili ART VM olusturmuyor.
 *
 * CIKTI NEREYE:
 *   DIKKAT (DUZELTME 2026-10-18): ilk surum yalnizca fd 2'ye
 *   (stderr) yaziyordu. Elle calistirildiginda gorunuyordu, ama
 *   init'in baslattigi servislerde stdio_to_kmsg ile cikti seri
 *   loga DUSMUYORDU. O yuzden simdi AYNI zamanda
 *   /data/dltrace.log dosyasina yaziyoruz (append).
 *   Dogrulama: dltrace.so haritada 7 map satiri ile vardi
 *   (yani LD_PRELOAD calisti) ama cikti yoktu -> dosya yolu.
 *
 * DERLEME (bionic, NDK'siz):
 *   aarch64-linux-gnu-gcc -shared -fPIC -nostdlib -O2 \
 *       -o dltrace.so dltrace.c
 * DT_NEEDED = 0. dlsym bionic global namespace'ten cozulur.
 * RTLD_NEXT = (void*)-1.
 */
typedef unsigned long ulong;

#define LOG_PATH "/data/dltrace.log"

/* aarch64 syscall numaralari */
#define SYS_write 64
#define SYS_openat 56
#define AT_FDCWD (-100)
#define O_WRONLY 1
#define O_CREAT 0100
#define O_APPEND 02000

static long sys_call3(long nr, long a0, long a1, long a2) {
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0") = a0;
    register long x1 __asm__("x1") = a1;
    register long x2 __asm__("x2") = a2;
    long ret;
    __asm__ volatile("svc 0" : "=r"(ret)
                     : "r"(x8), "r"(x0), "r"(x1), "r"(x2)
                     : "memory", "cc");
    return ret;
}

/* openat 4 argumanli (mode ayrica gerekli) */
static long sys_openat2(int flags, int mode) {
    register long x8 __asm__("x8") = SYS_openat;
    register long x0 __asm__("x0") = AT_FDCWD;
    register long x1 __asm__("x1") = (long)LOG_PATH;
    register long x2 __asm__("x2") = flags;
    register long x3 __asm__("x3") = mode;
    long ret;
    __asm__ volatile("svc 0" : "=r"(ret)
                     : "r"(x8), "r"(x0), "r"(x1), "r"(x2), "r"(x3)
                     : "memory", "cc");
    return ret;
}

static int g_fd = -1;

static void raw(const char* s, ulong n) {
    sys_call3(SYS_write, 2, (long)s, (long)n);        /* stderr */
    if (g_fd >= 0) sys_call3(SYS_write, g_fd, (long)s, (long)n);
}

static void put(const char* s) {
    ulong n = 0;
    while (s[n]) n++;
    raw(s, n);
}

/* bionic global namespace'ten cozulecek (biz tanimlamiyoruz) */
void* dlsym(void* handle, const char* sym);

#define RTLD_NEXT_ ((void*)-1)

typedef void* (*dl_fn)(const char*, int);
typedef void* (*ext_fn)(const char*, int, void*);

void* dlopen(const char* path, int flags) {
    dl_fn real = (dl_fn)dlsym(RTLD_NEXT_, "dlopen");
    put("DLOPEN \"");
    if (path) put(path); else put("(null)");
    put("\" ");
    if (!real || real == (dl_fn)dlopen) { put("-> GERCEK COZULEMEDI\n"); return 0; }
    void* h = real(path, flags);
    put(h ? "-> TAMAM\n" : "-> BASARISIZ\n");
    return h;
}

/* bionic'nin asil VM yukleme yolu (AndroidRuntime::startVm) */
void* android_dlopen_ext(const char* path, int flags, void* ns);
void* android_dlopen_ext_namespace(const char* path, int flags, void* caller);

void* android_dlopen_ext(const char* path, int flags, void* ns) {
    ext_fn real = (ext_fn)dlsym(RTLD_NEXT_, "android_dlopen_ext");
    put("EXT \"");
    if (path) put(path); else put("(null)");
    put("\" ");
    if (!real || real == (ext_fn)android_dlopen_ext) { put("-> GERCEK COZULEMEDI\n"); return 0; }
    void* h = real(path, flags, ns);
    put(h ? "-> TAMAM\n" : "-> BASARISIZ\n");
    return h;
}

void* android_dlopen_ext_namespace(const char* path, int flags, void* caller) {
    ext_fn real = (ext_fn)dlsym(RTLD_NEXT_, "android_dlopen_ext_namespace");
    put("EXTNS \"");
    if (path) put(path); else put("(null)");
    put("\" ");
    if (!real || real == (ext_fn)android_dlopen_ext_namespace) { put("-> GERCEK COZULEMEDI\n"); return 0; }
    void* h = real(path, flags, caller);
    put(h ? "-> TAMAM\n" : "-> BASARISIZ\n");
    return h;
}

__attribute__((constructor)) static void banner(void) {
    g_fd = (int)sys_openat2(O_WRONLY | O_CREAT | O_APPEND, 0666);
    put("\n=== dltrace yuklendi (PID asagida gorunur) ===\n");
    put("DLOPEN-COUNT-BASLADI\n");
}