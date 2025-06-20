#ifndef CHECK_WM_RESTART_H
#define CHECK_WM_RESTART_H

#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

// Check difference between previous and current 'WM_S0' atom to detect WM restart
bool check_wm_restart(Display* display, Window root) {
  static Window previous_owner = None;

  Atom wm_s0 = XInternAtom(display, "WM_S0", False);
  Window owner = XGetSelectionOwner(display, wm_s0);

  bool wm_restart = (previous_owner != None &&
                     owner != previous_owner);

  previous_owner = owner;

  return wm_restart;
}

#endif
