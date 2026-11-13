/*
 * Huawei kutuphanesi kullanim kaniti -- OTOMATIK BAGIMLILIK COZUCU ile.
 *
 * SORUN: Huawei bazi sistem kutuphanelerini (libandroid_runtime.so) yamalamis
 * ama ihtiyac duyduklarini DT_NEEDED ile bildirmemis. Bu bir "eksik sembol"
 * zinciri uretiyor:
 *     register_android_functions           -> libhwsqlite_jni.so
 *     SurfaceComposerClient::Transaction... -> libgui.so
 * Ilkini cozmek bir sonrakini ortaya cikariyor.
 *
 * TUMUNU on yuklemek ise calismiyor: libbluetooth.so'nun constructor'i binder
 * service manager istiyor ve sureci SIGABRT ile olduruyor:
 *     FATAL:hal_version_manager.h(91)] Check failed: service_manager != nullptr.
 *
 * COZUM: dongusel cozucu.
 *   1) hedef kutuphaneyi dlopen et
 *   2) hata "cannot locate symbol X" ise X'in TANIMLAYICISINI sistem
 *      kutuphaneleri arasinda ara (readelf yerine ELF dynsym'i okuyarak)
 *   3) sadece o kutuphaneyi RTLD_GLOBAL ile on yukle
 *   4) tekrarla  (en fazla N tur)
 * Bu, Zygote'un yaptigi seyin minimal bir taklidi: eksik bagimliliklari
 * tembel cozmek yerine, gereken minimumu yuklemek.
 */
#include <dirent.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <elf.h>

/* ---------------------------------------------------------------- ELF okuma */
struct sec { unsigned off, size, entsz; unsigned link; unsigned type; };
struct elfinfo { const unsigned char *map; size_t len;
                 const char *symtab; const char *strtab; size_t symcount; };

static int elf_load(const char *path, struct elfinfo *o)
{
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    if (n < (long)sizeof(Elf64_Ehdr)) { fclose(f); return -1; }
    unsigned char *b = malloc(n);
    if (!b) { fclose(f); return -1; }
    if (fread(b, 1, n, f) != (size_t)n) { free(b); fclose(f); return -1; }
    fclose(f);
    const Elf64_Ehdr *eh = (const Elf64_Ehdr *)b;
    if (memcmp(eh->e_ident, ELFMAG, 4) || eh->e_ident[EI_CLASS] != ELFCLASS64) {
        free(b); return -1;
    }
    o->map = b; o->len = n;
    o->symtab = NULL; o->strtab = NULL; o->symcount = 0;

    if (eh->e_shoff == 0) return 0;
    const Elf64_Shdr *sh = (const Elf64_Shdr *)(b + eh->e_shoff);
    if (eh->e_shnum > 256 || eh->e_shoff + (long)eh->e_shnum * eh->e_shentsize > n) {
        return 0;
    }
    /* tum bolumleri tara: bir sembolun adi bir baska bolumun strtab'inda */
    for (int i = 0; i < eh->e_shnum; i++) {
        if (sh[i].sh_type != SHT_DYNSYM && sh[i].sh_type != SHT_SYMTAB) continue;
        if (sh[i].sh_link >= eh->e_shnum) continue;
        const Elf64_Shdr *str = &sh[sh[i].sh_link];
        if (sh[i].sh_offset + sh[i].sh_size > (unsigned)o->len) continue;
        if (str->sh_offset + str->sh_size > (unsigned)o->len) continue;
        o->symtab = (const char *)(b + sh[i].sh_offset);
        o->strtab = (const char *)(b + str->sh_offset);
        o->symcount = sh[i].sh_size / sizeof(Elf64_Sym);
        break;
    }
    return 0;
}

static int elf_defines(const char *path, const char *sym)
{
    struct elfinfo o;
    if (elf_load(path, &o) != 0) return 0;
    int found = 0;
    if (o.symtab) {
        const Elf64_Sym *s = (const Elf64_Sym *)o.symtab;
        for (size_t i = 0; i < o.symcount; i++) {
            if (!s[i].st_name) continue;
            if (!s[i].st_shndx) continue;              /* UND -> tanim degil */
            unsigned bind = ELF64_ST_BIND(s[i].st_info);
            if (bind != STB_GLOBAL && bind != STB_WEAK) continue;
            if (strcmp(o.strtab + s[i].st_name, sym) == 0) { found = 1; break; }
        }
    }
    free((void *)o.map);
    return found;
}

/* sembolu tanimlayan kutuphaneyi bul */
static int find_definer(const char *sym, char *out, size_t outsz)
{
    static const char *dirs[] = {
        "/system/lib64", "/vendor/lib64", "/odm/lib64", NULL
    };
    for (int di = 0; dirs[di]; di++) {
        DIR *d = opendir(dirs[di]);
        if (!d) continue;
        struct dirent *e;
        while ((e = readdir(d))) {
            size_t n = strlen(e->d_name);
            if (n < 4 || strcmp(e->d_name + n - 3, ".so")) continue;
            char p[512];
            snprintf(p, sizeof p, "%s/%s", dirs[di], e->d_name);
            if (elf_defines(p, sym)) {
                snprintf(out, outsz, "%s", p);
                closedir(d);
                return 1;
            }
        }
        closedir(d);
    }
    return 0;
}

/* ------------------------------------------------------------------ hedef */
struct target { const char *lib; const char *sym; const char *note; };

static const struct target T[] = {
    {"/system/lib64/libace.z.so", NULL, "ArkUI/ArkTS motoru (15 MB)"},
    {"/system/lib64/libace_engine_qjs.z.so", NULL, "ACE QuickJS motoru"},
    {"/system/lib64/libace_engine_declarative.z.so", NULL, "ACE declarative"},
    {"/system/lib64/libace_engine_declarative_ark.z.so", NULL, "ACE ArkTS"},
    {"/system/lib64/libhwsqlite_jni.so", NULL, "SQLite sarmalayici"},
    {"/system/lib64/libhwkeystore_jni.so", NULL, "Keystore JNI"},
    {"/system/lib64/libhwspaceopt.so", NULL, "Bellek alan optimizasyonu"},
    {"/system/lib64/libhwui.so", NULL, "Huawei HWUI"},
    {"/system/lib64/libhwlog.so", "AndroidJanklogIsframetest", "janklog (saf)"},
    {"/system/lib64/libhuaweicust.so", NULL, "cust yapilandirma"},
};

#define MAXPRELOAD 40
static char preloaded[MAXPRELOAD][512];
static int npre = 0;

/* Bilinen, Elle dogrulanmis saglayicilar (tohum).
 *
 * Huawei bazi sistem kutuphanelerini yamalamis ve gereken DT_NEEDED
 * kayitlarini eklememis. readelf ile dogruladigimiz tanimlayicilar:
 *   register_android_functions  -> libhwsqlite_jni.so, libsqlite.so
 * Bunlari bastan yukleyerek cozucuye devam ediyoruz; kalanlar otomatik
 * bulunsun.
 */
/* Bilinen saglayicilar (tohum).
 *
 * DENENDI VE ISE YARAMADI: libhwsqlite_jni.so + libsqlite.so'yu bastan
 * yuklemek SIGSEGV uretiyor (linker, libsqlite'nin bagimlilik zincirini
 * kurarken cokuyor). Oysa otomatik cozucu -- hicbir seyi on yuklemeden --
 * zaten 5/10 kutuphaneyi aciyor. On yuklemek risk, kazanc degil.
 *
 * Buradaki yorum, otomatik cozucunun neden on yuklemeye ihtiyac
 * duymadigini da aciklar: cozucu yalnizca bir sembolun ACIKCA tanimlayicisini
 * yukler (ornegin MetaData::createFromParcel -> libstagefright_foundation.so).
 * Bu kutuphaneler bagimsiz ortamda ayakta kalabiliyor.
 */
static void seed_preload(void)
{
    /* bilerek bos: asagidaki cozucu yeterli
     * (bkz. register_android_functions icin bkz. notlar) */
}

static void preload_by_symbol(const char *sym)
{
    char path[512];
    if (!find_definer(sym, path, sizeof path)) return;
    for (int i = 0; i < npre; i++)
        if (!strcmp(preloaded[i], path)) return;
    void *h = dlopen(path, RTLD_LAZY | RTLD_GLOBAL);
    if (h && npre < MAXPRELOAD) {
        snprintf(preloaded[npre++], 512, "%s", path);
        printf("      + on yuklendi: %-42s (%.50s)\n", path, sym);
    }
}

/* hata metninden "cannot locate symbol \"X\"" cek */
static int extract_symbol(const char *msg, char *out, size_t outsz)
{
    const char *p = strstr(msg, "cannot locate symbol \"");
    if (!p) return 0;
    p += strlen("cannot locate symbol \"");
    const char *q = strchr(p, '"');
    if (!q) return 0;
    size_t n = (size_t)(q - p);
    if (n >= outsz) n = outsz - 1;
    memcpy(out, p, n);
    out[n] = 0;
    return 1;
}

int main(void)
{
    unsigned n = sizeof(T) / sizeof(T[0]);
    int loaded = 0, called = 0, failed = 0;

    printf("================================================================\n");
    printf("  HarmonyOS kutuphanesi -- NDK/Bionic, otomatik bagimlilik cozucu\n");
    printf("================================================================\n\n");

    printf("[on yukleme] elle dogrulanmis saglayicilar\n");
    seed_preload();
    printf("   yuklendi: %d\n\n", npre);

    for (unsigned i = 0; i < n; i++) {
        const struct target *t = &T[i];
        printf("[%u/%u] %-42s\n", i + 1, n, t->lib);
        printf("        %s\n", t->note);

        void *h = NULL;
        /* dongu: eksik sembol bulundukca tanimlayicisini yukle */
        for (int attempt = 0; attempt < MAXPRELOAD; attempt++) {
            h = dlopen(t->lib, RTLD_NOW | RTLD_GLOBAL);
            if (h) break;
            const char *err = dlerror();
            char sym[512];
            if (!err || !extract_symbol(err, sym, sizeof sym)) {
                printf("        [X] %s\n", err ? err : "bilinmeyen hata");
                break;
            }
            printf("        eksik sembol: %.70s\n", sym);
            int before = npre;
            preload_by_symbol(sym);
            if (npre == before) {
                printf("        [X] sembolun tanimlayicisi BULUNAMADI\n");
                break;
            }
        }

        if (!h) { failed++; printf("\n"); continue; }
        loaded++;
        printf("        [OK] yuklendi\n");

        if (t->sym) {
            void *s = dlsym(h, t->sym);
            if (s) {
                int rc = ((int (*)(void))s)();
                printf("        [OK] %s() = %d\n", t->sym, rc);
                called++;
            }
        }
        printf("\n");
    }

    printf("================================================================\n");
    printf("  yuklenen : %d / %u\n", loaded, n);
    printf("  cagrilan : %d\n", called);
    printf("  on yuklenen kutuphane: %d\n", npre);
    printf("================================================================\n");
    return loaded > 0 ? 0 : 1;
}