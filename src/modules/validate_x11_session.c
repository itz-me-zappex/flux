#include <stdio.h>
#include <stdlib.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

#include "functions/get_wm_window.h"

/* Tries to open display and checks compatibility for EWMH */
int main() {
  Display *display = XOpenDisplay(NULL);

  if (!display) {
    return 1;
  }

  Window root = DefaultRootWindow(display);

  Window wm_window = get_wm_window(display, root);
  if (wm_window == None) {
    XCloseDisplay(display);
    return 2;
  }

  XCloseDisplay(display);
  return 0;
}
