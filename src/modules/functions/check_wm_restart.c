#include "check_wm_restart.h"

// Check difference between previous and current 'WM_S0' atom to detect WM restart
bool check_wm_restart(Display* display, Window root, Atom atom) {
  static Window previous_owner = None;

  Window owner = XGetSelectionOwner(display, atom);

  bool wm_restart = (previous_owner != None &&
                     owner != previous_owner);
  previous_owner = owner;

  return wm_restart;
}
