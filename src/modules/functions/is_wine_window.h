#ifndef IS_WINE_WINDOW_H
#define IS_WINE_WINDOW_H

#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

bool is_wine_window(Display* display, Window window);

#endif
