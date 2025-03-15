#ifndef GET_ACTIVE_WINDOW_H
#define GET_ACTIVE_WINDOW_H

#include <X11/Xlib.h>
#include <X11/Xatom.h>

Window get_active_window(Display* display, Window root, Atom atom);

#endif
