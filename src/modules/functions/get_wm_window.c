#include "get_wm_window.h"

// Get window manager XID using '_NET_SUPPORTING_WM_CHECK' atom, needed to include it to list of opened windows and skip event if 'XGetInputFocus()' returns smth else instead of WM XID
Window get_wm_window(Display* display, Window root) {
  Atom net_supporting_wm_check = XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", False);

  Window wm_window;
  Atom type;
  unsigned char *data = NULL;
  unsigned long windows_count, bytes_after;
  int format;

  int status = XGetWindowProperty(display, root, net_supporting_wm_check, 0, 1, False, XA_WINDOW,
                                  &type, &format, &windows_count, &bytes_after, &data);

  if (status == Success &&
      data) {
    wm_window = *(Window *)data;
  } else {
    wm_window = None;
  }

  if (data) {
    XFree(data);
  }

  return wm_window;
}
