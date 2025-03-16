#include <stdlib.h>
#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>

#include "functions/get_opened_windows.h"

// Minimize window if passed window ID is valid
int main(int argc, char *argv[]) {
  if (argc != 2) {
    return 1;
  }

  Display *display = XOpenDisplay(NULL);

  if (!display) {
    return 1;
  }

  Window root = DefaultRootWindow(display);
  Window window = strtoul(argv[1], NULL, 0);
  Atom net_client_list_stacking = XInternAtom(display, "_NET_CLIENT_LIST_STACKING", False);
  unsigned long opened_windows_count;
  Window *opened_windows = get_opened_windows(display, root, &opened_windows_count, net_client_list_stacking);

  if (!opened_windows) {
    XCloseDisplay(display);
    return 1;
  }

  bool window_exists = false;

  for (unsigned long i = 0; i < opened_windows_count; i++) {
    if (opened_windows[i] == window) {
      window_exists = true;
      break;
    }
  }

  XFree(opened_windows);

  if (window_exists) {
    XIconifyWindow(display, window, DefaultScreen(display));
    XFlush(display);
  }

  XCloseDisplay(display);

  if (window_exists) {
    return 0;
  } else {
    return 1;
  }
}
