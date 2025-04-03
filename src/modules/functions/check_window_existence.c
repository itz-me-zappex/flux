#include "check_window_existence.h"

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

  XFree(opened_windows);

  return window_exists;
}
