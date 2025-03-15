#ifndef GET_WINDOW_PROCESS_H
#define GET_WINDOW_PROCESS_H

#include <X11/Xlib.h>
#include <X11/extensions/XRes.h>

pid_t get_window_process(Display* display, Window window_id);

#endif
