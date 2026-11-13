/*
 * Minimal ptrace-based syscall tracer for aarch64 Linux.
 * Usage: ./mini_strace [-f] [-tt] [-o output_file] <command> [args...]
 *
 * Cross-compile: aarch64-linux-gnu-gcc -static -O2 -o mini_strace mini_strace.c
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/user.h>
#include <sys/syscall.h>
#include <errno.h>
#include <signal.h>
#include <time.h>

#ifndef PTRACE_GETREGS
#define PTRACE_GETREGS 12
#endif
#ifndef PTRACE_SETREGS
#define PTRACE_SETREGS 13
#endif
#ifndef PTRACE_SYSCALL
#define PTRACE_SYSCALL 24
#endif
#ifndef PTRACE_SETOPTIONS
#define PTRACE_SETOPTIONS 0x4200
#endif
#ifndef PTRACE_O_TRACESYSGOOD
#define PTRACE_O_TRACESYSGOOD 1
#endif
#ifndef NT_PRSTATUS
#define NT_PRSTATUS 1
#endif

static int print_times = 0;
static FILE *out = NULL;

static const char *aarch64_syscall_names[] = {
    "io_setup", "io_destroy", "io_submit", "io_cancel", "io_getevents",
    "setxattr", "lsetxattr", "fsetxattr", "getxattr", "lgetxattr",
    "fgetxattr", "listxattr", "llistxattr", "flistxattr", "removexattr",
    "lremovexattr", "fremovexattr", "getcwd", "lookup_dcookie", "eventfd2",
    "epoll_create1", "epoll_ctl", "epoll_pwait", "dup", "dup3",
    "dup2", "dup", "fcntl", "fanotify_init", "fanotify_mark",
    "inotify_init1", "inotify_add_watch", "inotify_rm_watch", "ioctl", "ioprio_set",
    "ioprio_get", "flock", "flock", "fstatfs", "statfs",
    "truncate", "ftruncate", "fallocate", "fadvise64", "fadvise64_64",
    "syncfs", "sync", "mount", "umount2", "swapon",
    "swapoff", "getpid", "getppid", "getuid", "getgid",
    "geteuid", "getegid", "gettid", "setreuid", "setregid",
    "setgroups", "setfsuid", "setfsgid", "times", "ptrace",
    "getuid", "getgid", "geteuid", "getegid", "setuid",
    "setgid", "seteuid", "setegid", "getresuid", "getresgid",
    "setresuid", "setresgid", "getpgid", "setpgid", "getrlimit",
    "setrlimit", "getrusage", "gettimeofday", "time", "gettimeofday",
    "clock_gettime", "clock_settime", "clock_adjtime", "adjtimex", "getrandom",
    "pidfd_open", "clone3", "close_range", "openat2", "pidfd_getfd",
    "process_madvise", "epoll_pwait2", "mount_setattr", "landlock_create_ruleset",
    "landlock_add_rule", "landlock_restrict_self", "memfd_secret", "process_mrelease",
    "futex_waitv", "set_mempolicy_home_node", "futex", "sendmmsg", "recvmmsg",
    "sync", "nsenter", "process_vm_readv", "process_vm_writev", "kcmp",
    "finit_module", "sched_setattr", "sched_getattr", "renameat2", "seccomp",
    "getrandom", "open_by_handle_at", "statx", "preadv2", "pwritev2",
    "arch_prctl", "arch_prctl", "arch_prctl", "arch_prctl", "arch_prctl",
    "io_uring_setup", "io_uring_enter", "io_uring_register", "open_tree", "move_mount",
    "fsopen", "fsconfig", "fsmount", "fspick", "pidfd_send_signal",
    "io_uring_register", "io_uring_enter", "io_uring_setup", "open_tree", "move_mount",
    "fsopen", "fsconfig", "fsmount", "fspick", "pidfd_send_signal",
    "clone3", "close_range", "openat2", "pidfd_getfd", "process_madvise",
    "epoll_pwait2", "mount_setattr", "landlock_create_ruleset", "landlock_add_rule",
    "landlock_restrict_self", "memfd_secret", "process_mrelease", "futex_waitv",
    "set_mempolicy_home_node", "membarrier_user", "memfd_secret", "process_mrelease",
};

static void print_timestamp(void) {
    if (!print_times) return;
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    fprintf(out, "%ld.%06ld ", ts.tv_sec, ts.tv_nsec / 1000);
}

static const char *syscall_name(long nr) {
    if (nr >= 0 && nr < (long)(sizeof(aarch64_syscall_names)/sizeof(aarch64_syscall_names[0])))
        return aarch64_syscall_names[nr];
    return "unknown";
}

int main(int argc, char *argv[]) {
    int opt;
    int status;
    pid_t child;
    long syscall_nr;
    struct user_regs_struct regs;
    int arg_offset = 1;

    out = stdout;

    while ((opt = getopt(argc, argv, "to:")) != -1) {
        switch (opt) {
            case 't': print_times = 1; break;
            case 'o': out = fopen(optarg, "w"); if (!out) { perror("fopen"); return 1; } break;
            default: fprintf(stderr, "Usage: %s [-t] [-o file] command [args]\n", argv[0]); return 1;
        }
    }

    if (optind >= argc) {
        fprintf(stderr, "Usage: %s [-t] [-o file] command [args]\n", argv[0]);
        return 1;
    }

    child = fork();
    if (child == 0) {
        ptrace(PTRACE_TRACEME, 0, NULL, NULL);
        raise(SIGSTOP);
        execvp(argv[optind], &argv[optind]);
        perror("execvp");
        _exit(127);
    }

    waitpid(child, &status, 0);

    if (WIFSTOPPED(child)) {
        ptrace(PTRACE_SETOPTIONS, child, 0, PTRACE_O_TRACESYSGOOD);
        ptrace(PTRACE_SYSCALL, child, NULL, NULL);
    }

    while (1) {
        waitpid(child, &status, 0);

        if (WIFEXITED(status)) {
            fprintf(out, "exit_group(%d) = 0\n", WEXITSTATUS(status));
            break;
        }
        if (WIFSIGNALED(status)) {
            fprintf(out, "+++ killed by signal %d +++\n", WTERMSIG(status));
            break;
        }
        if (WIFSTOPPED(status)) {
            int sig = WSTOPSIG(status);
            if (sig == (SIGTRAP | 0x80)) {
                ptrace(PTRACE_GETREGS, child, NULL, &regs);
                syscall_nr = regs.regs[8];

                print_timestamp();
                fprintf(out, "%ld(", syscall_nr);
                for (int i = 0; i < 6; i++) {
                    fprintf(out, "0x%lx", (unsigned long)regs.regs[i]);
                    if (i < 5) fprintf(out, ", ");
                }
                fprintf(out, ")");

                ptrace(PTRACE_SINGLESTEP, child, NULL, NULL);
                waitpid(child, &status, 0);
                ptrace(PTRACE_GETREGS, child, NULL, &regs);
                long ret = regs.regs[0];

                fprintf(out, " = %ld\n", ret);

                ptrace(PTRACE_SYSCALL, child, NULL, NULL);
            } else {
                ptrace(PTRACE_SYSCALL, child, NULL, NULL);
            }
        }
    }

    if (out != stdout) fclose(out);
    return 0;
}
