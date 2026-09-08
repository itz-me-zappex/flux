#ifndef WINDOW_H
#define WINDOW_H

#include <stdlib.h>
#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

bool check_window_existence(Display* display, Window root, Window window);
bool check_wm_restart(Display* display, Window root);
Window get_active_window(Display* display, Window root);
Window get_input_focus(Display* display);
Window* get_opened_windows(Display* display, Window root, unsigned long *opened_windows_count);
Window get_wm_window(Display* display, Window root);
bool is_wine_window(Display* display, Window window);

#endif
