#include <stdlib.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

int main(int argc, char *argv[]) {
	if (argc != 2) {
		return 1;
	}

	Window window = strtoul(argv[1], NULL, 0);;
	Display *display = XOpenDisplay(NULL);

	if (!display) {
		return 1;
	}

	XIconifyWindow(display, window, DefaultScreen(display));
	XFlush(display);

	XCloseDisplay(display);
	return 0;
}