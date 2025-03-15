#ifndef GET_WM_WINDOW_H
#define GET_WM_WINDOW_H

#include <X11/Xlib.h>
#include <X11/Xatom.h>

Window get_wm_window(Display* display, Window root, Atom atom);

#endif
