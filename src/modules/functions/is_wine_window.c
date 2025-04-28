#include "is_wine_window.h"

// Check whether that is Wine/Proton window or not by checking '_WINE_HWND_STYLE' atom existence
bool is_wine_window(Display* display, Window window) {
  Atom wine_hwnd_style = XInternAtom(display, "_WINE_HWND_STYLE", False);

  Atom type;
  unsigned char *data = NULL;
  unsigned long windows_count, bytes_after;
  int format;

  int status = XGetWindowProperty(display, window, wine_hwnd_style, 0, 1, False, XA_CARDINAL,
                                  &type, &format, &windows_count, &bytes_after, &data);

  if (data) {
    XFree(data);
  }

  if (status == Success &&
      type != None) {
    return true;
  }

  return false;
}
