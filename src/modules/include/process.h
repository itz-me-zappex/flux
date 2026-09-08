#ifndef PROCESS_H
#define PROCESS_H

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/extensions/XRes.h>

pid_t get_window_process(Display* display, Window window_id);
bool get_cpu_time(char *path, unsigned long *utime, unsigned long *stime);
bool is_process_cpu_idle(pid_t pid);

#endif
