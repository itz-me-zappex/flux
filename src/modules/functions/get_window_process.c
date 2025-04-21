#include "get_window_process.h"

// Get process of window using XRes extension ('_NET_WM_PID' is unreliable)
pid_t get_window_process(Display* display, Window window_id) {
  pid_t window_process;
  XResClientIdSpec client_spec;
  client_spec.client = window_id;
  client_spec.mask = XRES_CLIENT_ID_PID_MASK;
  long elements;
  XResClientIdValue *client_ids = NULL;

  int status = XResQueryClientIds(display, 1, &client_spec, &elements, &client_ids);

  if (status == Success &&
      client_ids) {
    for (long i = 0; i < elements; i++) {
      if (window_id > 0) {
        window_process = XResGetClientPid(&client_ids[i]);
        break;
      }
    }
  } else {
    window_process = 0;
  }

  if (client_ids) {
    XResClientIdsDestroy(elements, client_ids);
  }

  return window_process;
}
