#!/usr/bin/env python3
"""Capture or click an explicitly identified Roblox Studio XWayland window."""
import argparse
import ctypes
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('window', help='X11 window ID, e.g. 0x26000c5')
    actions = parser.add_subparsers(dest='action', required=True)
    capture = actions.add_parser('capture')
    capture.add_argument('output', type=Path)
    click = actions.add_parser('click')
    click.add_argument('x', type=int)
    click.add_argument('y', type=int)
    args = parser.parse_args()
    window = int(args.window, 0)
    assert window > 0, 'positive X11 window ID required'
    name = hex(window)
    info = subprocess.run(['xprop', '-id', name, 'WM_CLASS'], check=True, capture_output=True, text=True).stdout
    if '"robloxstudiobeta.exe"' not in info.lower():
        raise RuntimeError('window is not a Roblox Studio XWayland window')
    if args.action == 'capture':
        subprocess.run(['magick', 'import', '-window', name, str(args.output)], check=True)
        return

    x11 = ctypes.CDLL('libX11.so.6')
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError('cannot open X11 display')

    class WindowAttributes(ctypes.Structure):
        _fields_ = [('x', ctypes.c_int), ('y', ctypes.c_int), ('width', ctypes.c_int), ('height', ctypes.c_int),
                    ('border_width', ctypes.c_int), ('depth', ctypes.c_int), ('visual', ctypes.c_void_p),
                    ('root', ctypes.c_ulong), ('window_class', ctypes.c_int), ('bit_gravity', ctypes.c_int),
                    ('win_gravity', ctypes.c_int), ('backing_store', ctypes.c_int), ('backing_planes', ctypes.c_ulong),
                    ('backing_pixel', ctypes.c_ulong), ('save_under', ctypes.c_int), ('colormap', ctypes.c_ulong),
                    ('map_installed', ctypes.c_int), ('map_state', ctypes.c_int), ('all_event_masks', ctypes.c_long),
                    ('your_event_mask', ctypes.c_long), ('do_not_propagate_mask', ctypes.c_long),
                    ('override_redirect', ctypes.c_int), ('screen', ctypes.c_void_p)]

    class ButtonEvent(ctypes.Structure):
        _fields_ = [('type', ctypes.c_int), ('serial', ctypes.c_ulong), ('send_event', ctypes.c_int),
                    ('display', ctypes.c_void_p), ('window', ctypes.c_ulong), ('root', ctypes.c_ulong),
                    ('subwindow', ctypes.c_ulong), ('time', ctypes.c_ulong), ('x', ctypes.c_int), ('y', ctypes.c_int),
                    ('x_root', ctypes.c_int), ('y_root', ctypes.c_int), ('state', ctypes.c_uint),
                    ('button', ctypes.c_uint), ('same_screen', ctypes.c_int)]

    class Event(ctypes.Union):
        _fields_ = [('button', ButtonEvent), ('padding', ctypes.c_long * 24)]

    try:
        attrs = WindowAttributes()
        x11.XGetWindowAttributes.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(WindowAttributes)]
        if not x11.XGetWindowAttributes(display, window, ctypes.byref(attrs)):
            raise RuntimeError('cannot read window geometry')
        if attrs.map_state != 2 or not (0 <= args.x < attrs.width and 0 <= args.y < attrs.height):
            raise ValueError('window must be mapped and click coordinates must be inside it')
        x11.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_long, ctypes.POINTER(Event)]
        for event_type, mask, state in ((4, 1 << 2, 0), (5, 1 << 3, 1 << 8)):
            event = Event()
            event.button.type, event.button.display, event.button.window = event_type, display, window
            event.button.root = attrs.root
            event.button.x, event.button.y = args.x, args.y
            event.button.x_root, event.button.y_root = attrs.x + args.x, attrs.y + args.y
            event.button.state, event.button.button, event.button.same_screen = state, 1, 1
            if not x11.XSendEvent(display, window, 0, mask, ctypes.byref(event)):
                raise RuntimeError('X11 rejected the click event')
        x11.XFlush.argtypes = [ctypes.c_void_p]
        x11.XFlush(display)
    finally:
        x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
        x11.XCloseDisplay(display)


if __name__ == '__main__':
    main()
