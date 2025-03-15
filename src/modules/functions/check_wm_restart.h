#ifndef CHECK_WM_RESTART_H
#define CHECK_WM_RESTART_H

#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

bool check_wm_restart(Display* display, Window root, Atom atom);

#endif
