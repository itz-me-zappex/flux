#include "get_input_focus.h"

// Fallback, get window XID from X server if '_NET_ACTIVE_WINDOW' is zero
Window get_input_focus(Display* display) {
  int revert;
  Window active_window;

  XGetInputFocus(display, &active_window, &revert);

  return active_window;
}
