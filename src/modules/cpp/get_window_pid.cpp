#include <X11/Xlib.h>
#include <X11/extensions/XRes.h>
#include <iostream>
#include <cstdlib>

/*
	This code uses libxres to obtain window PID without asking window for '_NET_WM_PID'
	Aims to be used inside of project and not manually by unknowledged user, that is why there is no "dumbass protections"
	There is few reasons exists to use it instead of 'xprop -id <window_id> _NET_WM_PID':
		1. Window returns fake PID (from sandbox) if app runs with tool like 'firejail' which uses PID namespaces.
		2. Some windows like 'glxgears', 'vkcube' and 'noisetorch' do not have '_NET_WM_PID' property and there is no other way to get their PIDs but using libxres.
		3. This code prints only PID and nothing else, that makes it easier to use in my project than 'xprop' tool which requires output formatting to get PID number.
*/

// Expected argument is a single hexadecimal window ID, e.g. './get_window_pid 0x3e0003e'
int main(int argc, char *argv[]) {
	// Convert argument string to a window ID
	Window window_id = strtoul(argv[1], nullptr, 16);
	// Attempt to open X server
	Display *display = XOpenDisplay(nullptr);
	if (!display) {
		return 1;
	}
	// Create specification structure to query it with window ID
	XResClientIdSpec client_spec;
	client_spec.client = window_id;
	client_spec.mask = XRES_CLIENT_ID_PID_MASK;
	// Define 'num_ids' to store count of client IDs and 'XResClientIdValue' array to store their values
	long num_ids = 0;
	XResClientIdValue *client_ids = nullptr;
	// Get client IDs with PIDs
	Status status = XResQueryClientIds(display, 1, &client_spec, &num_ids, &client_ids);
	// Exit with an error is something is wrong
	if (status == Success && num_ids > 0) {
		// Check all client IDs
		for (long i = 0; i < num_ids; ++i) {
			// Get PID associated with current client ID
			pid_t pid = XResGetClientPid(&client_ids[i]);
			// Print PID and break loop if exists
			if (pid > 0) {
				std::cout << pid << std::endl;
				break;
			}
		}
	} else {
		return 1;
	}
	// Exit safely
	XResClientIdsDestroy(num_ids, client_ids);
	XCloseDisplay(display);
	return 0;
}