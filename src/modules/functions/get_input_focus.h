#ifndef GET_INPUT_FOCUS_H
#define GET_INPUT_FOCUS_H

#include <X11/Xlib.h>

// Fallback, get window XID from X server if '_NET_ACTIVE_WINDOW' is zero
Window get_input_focus(Display* display) {
  Window active_window;

  int revert;
  XGetInputFocus(display, &active_window, &revert);

  return active_window;
}

#endif
