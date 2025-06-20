#ifndef CHECK_WINDOW_EXISTENCE_H
#define CHECK_WINDOW_EXISTENCE_H

#include <stdlib.h>
#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

#include "get_opened_windows.h"

bool check_window_existence(Display* display, Window root, Window window) {
  unsigned long opened_windows_count;
  Window *opened_windows = get_opened_windows(display, root, &opened_windows_count);

  if (!opened_windows) {
    return false;
  }

  bool window_exists = false;

  for (unsigned long i = 0; i < opened_windows_count; i++) {
    if (opened_windows[i] == window) {
      window_exists = true;
      break;
    }
  }

  if (opened_windows) {
    XFree(opened_windows);
  }

  return window_exists;
}

#endif
