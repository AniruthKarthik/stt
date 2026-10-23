#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <signal.h>
#include <time.h>
#include <sys/epoll.h>
#include <sys/ioctl.h>
#include <linux/input.h>

#define MAX_DEVICES 64
#define TRIGGER_KEY KEY_F8
#define HOLD_THRESHOLD_SEC 0.45

static volatile int running = 1;
static char stt_bin_path[1024];

static void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

static double get_time_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static int device_supports_key(int fd, int keycode) {
    unsigned long ev_bits[1] = {0};
    if (ioctl(fd, EVIOCGBIT(0, sizeof(ev_bits)), ev_bits) < 0) return 0;
    if (!(ev_bits[0] & (1UL << EV_KEY))) return 0;

    unsigned char key_bits[KEY_MAX / 8 + 1] = {0};
    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(key_bits)), key_bits) < 0) return 0;

    return (key_bits[keycode / 8] & (1 << (keycode % 8))) != 0;
}

static void trigger_stt(const char *action) {
    char cmd[1200];
    snprintf(cmd, sizeof(cmd), "\"%s\" %s &", stt_bin_path, action);
    system(cmd);
}

int main(int argc, char **argv) {
    // Determine path to whisperstt / stt binary
    if (argc > 1) {
        snprintf(stt_bin_path, sizeof(stt_bin_path), "%s", argv[1]);
    } else {
        char exe_dir[1024];
        ssize_t len = readlink("/proc/self/exe", exe_dir, sizeof(exe_dir) - 1);
        if (len > 0) {
            exe_dir[len] = '\0';
            char *last_slash = strrchr(exe_dir, '/');
            if (last_slash) *last_slash = '\0';
            snprintf(stt_bin_path, sizeof(stt_bin_path), "%s/whisperstt", exe_dir);
        } else {
            snprintf(stt_bin_path, sizeof(stt_bin_path), "stt");
        }
    }

    signal(SIGTERM, handle_signal);
    signal(SIGINT, handle_signal);
    signal(SIGHUP, handle_signal);

    int epoll_fd = epoll_create1(0);
    if (epoll_fd < 0) {
        perror("epoll_create1");
        return 1;
    }

    int dev_fds[MAX_DEVICES];
    int dev_count = 0;

    // Scan /dev/input/event* devices
    for (int i = 0; i < MAX_DEVICES; i++) {
        char dev_path[64];
        snprintf(dev_path, sizeof(dev_path), "/dev/input/event%d", i);

        int fd = open(dev_path, O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;

        char name[256] = "Unknown";
        ioctl(fd, EVIOCGNAME(sizeof(name)), name);

        // Filter out virtual/ydotool devices
        if (strstr(name, "ydotoold") || strstr(name, "Virtual") || strstr(name, "uinput")) {
            close(fd);
            continue;
        }

        if (device_supports_key(fd, TRIGGER_KEY)) {
            struct epoll_event ev;
            ev.events = EPOLLIN;
            ev.data.fd = fd;
            if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &ev) == 0) {
                dev_fds[dev_count++] = fd;
                printf("[STT Daemon] Listening to: %s (%s)\n", dev_path, name);
            } else {
                close(fd);
            }
        } else {
            close(fd);
        }
    }

    if (dev_count == 0) {
        fprintf(stderr, "[STT Daemon] Error: No keyboard device found supporting KEY_F8.\n");
        close(epoll_fd);
        return 1;
    }

    printf("[STT Daemon] Ready. Monitoring %d device(s) for F8 key events...\n", dev_count);
    fflush(stdout);

    int is_recording = 0;
    double press_time = 0.0;
    struct epoll_event events[MAX_DEVICES];

    while (running) {
        int n = epoll_wait(epoll_fd, events, MAX_DEVICES, 1000);
        if (n < 0) continue;

        for (int i = 0; i < n; i++) {
            struct input_event ev;
            while (read(events[i].data.fd, &ev, sizeof(ev)) == sizeof(ev)) {
                if (ev.type == EV_KEY && ev.code == TRIGGER_KEY) {
                    if (ev.value == 1) { // Press
                        if (!is_recording) {
                            press_time = get_time_sec();
                            is_recording = 1;
                            printf("[STT Daemon] F8 pressed -> Starting recording\n");
                            fflush(stdout);
                            trigger_stt("start");
                        } else {
                            // Tapped while recording -> stop
                            is_recording = 0;
                            printf("[STT Daemon] F8 pressed while recording -> Stopping and transcribing\n");
                            fflush(stdout);
                            trigger_stt("stop");
                        }
                    } else if (ev.value == 0) { // Release
                        if (is_recording) {
                            double duration = get_time_sec() - press_time;
                            if (duration > HOLD_THRESHOLD_SEC) {
                                // User was holding F8 -> stop on release
                                is_recording = 0;
                                printf("[STT Daemon] F8 released after %.2fs hold -> Stopping and transcribing\n", duration);
                                fflush(stdout);
                                trigger_stt("stop");
                            } else {
                                // Short tap (<0.45s) -> keep recording in hands-free toggle mode
                                printf("[STT Daemon] F8 tapped (%.2fs) -> Continuing hands-free recording\n", duration);
                                fflush(stdout);
                            }
                        }
                    }
                    // ev.value == 2 is autorepeat; ignore it completely
                }
            }
        }
    }

    printf("[STT Daemon] Shutting down...\n");
    for (int i = 0; i < dev_count; i++) {
        close(dev_fds[i]);
    }
    close(epoll_fd);
    return 0;
}
