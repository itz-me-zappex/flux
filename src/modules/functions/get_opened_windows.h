#ifndef GET_OPENED_WINDOWS_H
#define GET_OPENED_WINDOWS_H

#include <X11/Xlib.h>
#include <X11/Xatom.h>

/* Get list of opened window XIDs using '_NET_CLIENT_LIST_STACKING' atom */
Window* get_opened_windows(Display* display, Window root, unsigned long *opened_windows_count) {
  unsigned char *data = NULL;

  unsigned long windows_count, bytes_after;
  int format;
  Atom type;
  Atom net_client_list_stacking = XInternAtom(display, "_NET_CLIENT_LIST_STACKING", False);
  int status = XGetWindowProperty(display, root, net_client_list_stacking, 0, ~0, False, XA_WINDOW,
                                  &type, &format, &windows_count, &bytes_after, &data);

  if (status != Success) {
    *opened_windows_count = 0;
    return NULL;
  }
  *opened_windows_count = windows_count;
  return (Window *)data;
}

#endif
