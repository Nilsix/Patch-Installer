"""Download the ReBalance of Souls patch next to this file.

For players who already have Python (with tkinter) and Git: nothing is
installed. Running it again updates the download in place and keeps the
launcher's settings.
"""
import os
import shutil
import subprocess
import sys

REPO_URL = os.environ.get("BROS_REPO_URL", "https://github.com/reBalance-Of-Souls/BROS-Patch.git")
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(BASE_DIR, "BROS-Patch")


def git(*args):
    return subprocess.run(["git", *args]).returncode == 0


def main():
    if shutil.which("git") is None:
        print("Git is not installed. Install it from https://git-scm.com/downloads, then run this again.")
        return 1
    try:
        import tkinter  # noqa: F401 -- the launcher's window is built with it
    except ImportError:
        print("Warning: this Python has no tkinter, and the launcher needs it.")

    if os.path.isdir(os.path.join(DEST, ".git")):
        print("Updating", DEST, "in place (your launcher settings are kept)", flush=True)
        ok = (git("-C", DEST, "config", "core.longpaths", "true")
              and git("-C", DEST, "remote", "set-url", "origin", REPO_URL)
              and git("-C", DEST, "fetch", "--progress", "origin")
              and git("-C", DEST, "reset", "-q", "--hard", "origin/main"))
    else:
        # The current files only, not the full history of every file: about
        # half the download. core.longpaths: some patch paths are longer than
        # the 260 characters Windows allows by default.
        print("Downloading the patch into", DEST, "(about 1.4 GB)", flush=True)
        ok = (git("-c", "core.longpaths=true", "clone", "--filter=blob:none", "--progress", REPO_URL, DEST)
              and git("-C", DEST, "config", "core.longpaths", "true"))

    print("Done." if ok else "The download did not finish: check your connection, then run this again.")
    return 0 if ok else 1


if __name__ == "__main__":
    code = main()
    input("Press Enter to close ")
    sys.exit(code)
