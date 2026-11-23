"""Entry point for our macOS build of Geraniums Pot (github.com/grigorusha/GeraniumsPot).

PyInstaller builds this file instead of upstream's main.py, so upstream's source stays unmodified.
It runs from the per-user data folder (the launcher cd's there), where Garden/, Photo/, fonts/ and
the icon png live.

What it changes:
- Tk is started before pygame (see run()).
- ./Photo becomes a symlink into the bundle (see _link_photos()).
- Each screen update first makes the window's alpha channel opaque (see _opaque_updates()), which
  fixes black boxes on markers during animations.
- Upstream writes its ini (the last opened puzzle) to "$HOME/Geraniums Pot <version>/" on
  non-Windows systems. We point that at the working directory instead, so nothing lands in the
  user's home folder.

Debug-only hooks (environment variables, off unless set):
- GP_DEBUG_SHOT=<file.png>: after each screen update (at most twice a second), save the window's
  contents to that file. Lets us check rendering without Screen Recording permission.
- GP_DEBUG_EVENTS="<seconds>:<action>;...": inject input. Actions: "ring" (left-click the center of
  the first ring), "click X Y" / "rclick X Y" (left/right click at window coords), "key NAME" (a
  pygame key name, e.g. F3 or space), "drop PATH" (drop a puzzle file on the window; relative to the
  working directory), "abortmodal" (cancel an open modal dialog), "quit". Each action and the move
  counter are logged to stderr. Note that F11/F12 with no file loaded yet (the built-in first
  puzzle) open the file dialog, as upstream does.
"""
import os
import sys
import threading
import time
import types

STATE_DIR = os.getcwd()


class _OsProxy(types.ModuleType):
    """The os module, except getenv("HOME") returns the working directory."""

    def __getattr__(self, name):
        return getattr(os, name)

    def getenv(self, key, default=None):
        if key == "HOME":
            return STATE_DIR
        return os.getenv(key, default)


def _load_upstream_glob():
    """Make "import glob" give upstream's glob.py (its global settings), not the stdlib module.

    Upstream's modules do "import glob as var". PyInstaller resolves "glob" to the stdlib module no
    matter what --paths says, so the build ships upstream's file as data (gp-glob.py) and we load it
    under that name before anything imports it. Nothing in the bundle needs the stdlib glob.
    """
    if not getattr(sys, "frozen", False):
        return  # from source, PYTHONPATH=Source already puts upstream's glob.py first
    import importlib.util

    spec = importlib.util.spec_from_file_location("glob", os.path.join(sys._MEIPASS, "gp-glob.py"))
    module = importlib.util.module_from_spec(spec)
    sys.modules["glob"] = module
    spec.loader.exec_module(module)


def _link_photos():
    """Point ./Photo at the bundle's read-only Photo folder (about 12 MB) instead of copying it.

    The symlink is refreshed on every launch, so it follows the app when it moves. A real Photo
    folder in the working directory is left alone.
    """
    if not getattr(sys, "frozen", False):
        return
    src = os.path.normpath(os.path.join(os.path.dirname(sys.executable), "..", "Resources", "Photo"))
    dst = os.path.join(STATE_DIR, "Photo")
    if not os.path.isdir(src) or (os.path.islink(dst) and os.readlink(dst) == src):
        return
    if os.path.islink(dst):
        os.remove(dst)
    if not os.path.exists(dst):
        os.symlink(src, dst)


def _abort_modal(log, t):
    import ctypes

    objc = ctypes.cdll.LoadLibrary("/usr/lib/libobjc.A.dylib")
    objc.objc_getClass.restype = objc.sel_registerName.restype = ctypes.c_void_p
    sel = objc.sel_registerName
    get = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p)(("objc_msgSend", objc))
    perform = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
                               ctypes.c_bool)(("objc_msgSend", objc))
    app = get(objc.objc_getClass(b"NSApplication"), sel(b"sharedApplication"))
    log(f"t={t:.1f}s abortmodal")
    perform(app, sel(b"performSelectorOnMainThread:withObject:waitUntilDone:"), sel(b"abortModal"), None, False)


def _opaque_updates():
    """Set the window's alpha to 255 before each pygame.display.update().

    On macOS the window surface is ARGB8888 (on Windows it has no alpha channel). Upstream draws
    each frame into game_scr, a plain Surface in the window's format, and copies it to the window,
    so a marker's transparent pixels arrive in the window with alpha 0. Presenting ignores alpha,
    so that frame looks right. But animation frames then alpha-blit each ring's rotated sprite onto
    the window without redrawing it, and pygame's blitter copies the source pixel outright where
    the destination alpha is 0. Wherever a transparent sprite pixel lands on such a pixel, the
    window turns black: black boxes on markers, seen on "Gear Mandorla" (2026-11-23).
    """
    import pygame

    real_update = pygame.display.update

    def update(*args, **kwargs):
        surf = pygame.display.get_surface()
        if surf is not None and surf.get_masks()[3]:
            surf.fill((0, 0, 0, 255), special_flags=pygame.BLEND_RGBA_MAX)
        return real_update(*args, **kwargs)

    pygame.display.update = update


def _install_debug_hooks():
    import pygame
    import glob as var  # upstream's glob.py (shadows the stdlib module, as in upstream's own builds)
    import work

    shot = os.environ.get("GP_DEBUG_SHOT")
    script = os.environ.get("GP_DEBUG_EVENTS")
    if not shot and not script:
        return
    log = lambda msg: print("[gp-debug] " + msg, file=sys.stderr, flush=True)
    t0 = time.monotonic()
    rings = {"list": None}

    # Remember the rings so "ring" can click one. main.py star-imports this, so patch before it loads.
    real_mmc = work.mouse_move_click

    def mouse_move_click(*args):
        rings["list"] = args[6]
        return real_mmc(*args)

    work.mouse_move_click = mouse_move_click

    pending = []
    for item in (script or "").split(";"):
        if item.strip():
            t, action = item.split(":", 1)
            pending.append((float(t), action.split()))
    pending.sort(key=lambda p: p[0])
    # "abortmodal" closes a modal dialog (e.g. F3's file dialog) as if canceled. The game loop is
    # blocked while the dialog is up, so this one runs on a timer thread and asks the main thread
    # to run [NSApp abortModal].
    for t, act in [p for p in pending if p[1][0] == "abortmodal"]:
        pending.remove((t, act))
        timer = threading.Timer(t, _abort_modal, args=(log, t))
        timer.daemon = True
        timer.start()

    def synth():
        out = []
        while pending and time.monotonic() - t0 >= pending[0][0]:
            _, act = pending.pop(0)
            log(f"t={time.monotonic() - t0:.1f}s {' '.join(act)} (moves before: {var.moves})")
            if act[0] in ("click", "rclick", "ring"):
                if act[0] == "ring":
                    # The rings are only known once the mouse has moved over the puzzle; until then,
                    # aim at the window's center.
                    r = next((r for r in rings["list"] or [] if r["type"] == 0), None)
                    w, h = pygame.display.get_surface().get_size()
                    pos = (int(r["center_x"]), int(r["center_y"])) if r else (w // 2, h // 2)
                    button = 1
                else:
                    pos, button = (int(act[1]), int(act[2])), 1 if act[0] == "click" else 3
                out.append(pygame.event.Event(pygame.MOUSEMOTION, pos=pos, rel=(0, 0), buttons=(0, 0, 0)))
                out.append(pygame.event.Event(pygame.MOUSEBUTTONDOWN, pos=pos, button=button))
                out.append(pygame.event.Event(pygame.MOUSEBUTTONUP, pos=pos, button=button))
            elif act[0] == "key":
                key = pygame.key.key_code(act[1])
                out.append(pygame.event.Event(pygame.KEYDOWN, key=key, mod=0, unicode="", scancode=0))
                out.append(pygame.event.Event(pygame.KEYUP, key=key, mod=0, unicode="", scancode=0))
            elif act[0] == "drop":
                out.append(pygame.event.Event(pygame.DROPFILE, file=os.path.abspath(" ".join(act[1:]))))
            elif act[0] == "quit":
                out.append(pygame.event.Event(pygame.QUIT))
        return out

    real_get = pygame.event.get

    def get(*args, **kwargs):
        return real_get(*args, **kwargs) + synth()

    pygame.event.get = get

    last = {"t": 0.0, "moves": 0}
    real_update = pygame.display.update

    def update(*args, **kwargs):
        real_update(*args, **kwargs)
        now = time.monotonic()
        if var.moves != last["moves"]:
            log(f"t={now - t0:.1f}s moves={var.moves} stack={var.moves_stack}")
            last["moves"] = var.moves
        if shot and now - last["t"] >= 0.5:
            surf = pygame.display.get_surface()
            if surf is not None:
                pygame.image.save(surf, shot)  # alpha is already 255 (_opaque_updates)
            last["t"] = now

    pygame.display.update = update


def run():
    _link_photos()
    # Tk must create the NSApplication before SDL does. Otherwise NSApp is SDL's SDLApplication,
    # and Tk 8.6.11+ aborts on its first color lookup ("-[SDLApplication macOSVersion]: unrecognized
    # selector") when main.py calls Tk(). With Tk first, SDL adopts Tk's NSApp.
    import tkinter

    tkinter.Tk().withdraw()  # also becomes tkinter's default root, which the file dialogs use

    _load_upstream_glob()
    import work

    work.os = _OsProxy("os")  # only work.py reads HOME (save_state and init_puzzle)
    _opaque_updates()
    _install_debug_hooks()
    import main  # noqa: F401  (upstream's main.py runs the program when imported)


run()
