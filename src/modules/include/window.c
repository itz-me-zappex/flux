#include "window.h"

/* Find window in stacking list */
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

  if (opened_windows) {
    XFree(opened_windows);
  }

  return window_exists;
}

/* Check difference between previous and current 'WM_S0' atom
 * to detect WM restart
 */
bool check_wm_restart(Display* display, Window root) {
  static Window previous_owner = None;

  Atom wm_s0 = XInternAtom(display, "WM_S0", False);
  Window owner = XGetSelectionOwner(display, wm_s0);

  bool wm_restart = (previous_owner != None &&
                     owner != previous_owner);

  previous_owner = owner;

  return wm_restart;
}

/* Get window XID using '_NET_ACTIVE_WINDOW' atom */
Window get_active_window(Display* display, Window root) {
  Window active_window;
  unsigned char *data = NULL;

  unsigned long windows_count, bytes_after;
  int format;
  Atom type;
  Atom net_active_window = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
  int status = XGetWindowProperty(display, root, net_active_window, 0, 1, False, XA_WINDOW,
                                  &type, &format, &windows_count, &bytes_after, &data);

  if (status == Success &&
      data) {
    active_window = *(Window *)data;
  } else {
    active_window = None;
  }

  if (data) {
    XFree(data);
  }

  return active_window;
}

/* Fallback, get window XID from X server if '_NET_ACTIVE_WINDOW' is zero */
Window get_input_focus(Display* display) {
  Window active_window;

  int revert;
  XGetInputFocus(display, &active_window, &revert);

  return active_window;
}

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

/* Get window manager XID using '_NET_SUPPORTING_WM_CHECK' atom
 * Needed to include it to list of opened windows and skip event
 * if 'XGetInputFocus()' returns something else instead of XID
 */
Window get_wm_window(Display* display, Window root) {
  Window wm_window;
  unsigned char *data = NULL;

  unsigned long windows_count, bytes_after;
  int format;
  Atom type;
  Atom net_supporting_wm_check = XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", False);
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

/* Check whether that is Wine/Proton window or not
 * by checking '_WINE_HWND_STYLE' atom existence
 */
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
