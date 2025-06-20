#ifndef IS_WINE_WINDOW_H
#define IS_WINE_WINDOW_H

#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

// Check whether that is Wine/Proton window or not by checking '_WINE_HWND_STYLE' atom existence
bool is_wine_window(Display* display, Window window) {
  unsigned char *data = NULL;

  unsigned long windows_count, bytes_after;
  int format;
  Atom type;
  Atom wine_hwnd_style = XInternAtom(display, "_WINE_HWND_STYLE", False);
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

#endif
