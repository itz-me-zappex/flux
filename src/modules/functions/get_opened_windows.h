#ifndef GET_OPENED_WINDOWS_H
#define GET_OPENED_WINDOWS_H

#include <X11/Xlib.h>
#include <X11/Xatom.h>

Window* get_opened_windows(Display* display, Window root, unsigned long *opened_windows_count);

#endif
