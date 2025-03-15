#include "get_active_window.h"

// Get window XID using '_NET_ACTIVE_WINDOW' atom
Window get_active_window(Display* display, Window root, Atom atom) {
  Window active_window;
  Atom type;
  unsigned char *data = NULL;
  unsigned long windows_count, bytes_after;
  int format;

  int status = XGetWindowProperty(display, root, atom, 0, 1, False, XA_WINDOW,
                                  &type, &format, &windows_count, &bytes_after, &data);

  if (status == Success &&
      data) {
    active_window = *(Window *)data;
  } else {
    active_window = None;
  }

  XFree(data);

  return active_window;
}
