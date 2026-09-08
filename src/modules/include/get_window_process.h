#ifndef GET_WINDOW_PROCESS_H
#define GET_WINDOW_PROCESS_H

#include <X11/Xlib.h>
#include <X11/extensions/XRes.h>

/* Get process ID of window using XRes extension
 * In this way because '_NET_WM_PID' is unreliable
 */
pid_t get_window_process(Display* display, Window window_id) {
  pid_t window_process;
  XResClientIdValue *client_ids = NULL;

  XResClientIdSpec client_spec = {
    .client = window_id,
    .mask = XRES_CLIENT_ID_PID_MASK,
  };
  long elements;
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

#endif
