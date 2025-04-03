#ifndef CHECK_WINDOW_EXISTENCE_H
#define CHECK_WINDOW_EXISTENCE_H

#include <stdlib.h>
#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

#include "get_opened_windows.h"

bool check_window_existence(Display* display, Window root, Window window);

#endif
