#!/bin/sh
# ReBalance of Souls -- macOS installer
#
#   sh InstallerMac.sh             install into BROS-Patch/ next to this file
#   sh InstallerMac.sh <folder>    install into <folder> instead
#
# Bleach Rebirth of Souls has no macOS version, so this only helps when the
# game runs through a Windows compatibility layer. It installs git and a
# Python with tkinter through Homebrew (Homebrew's own Python has no tkinter
# without python-tk), then downloads the current patch files only, not the full
# history of every file. Run it again at any time: it updates the folder in
# place and keeps the launcher's settings.

set -eu

REPO_URL="${BROS_REPO_URL:-https://github.com/reBalance-Of-Souls/BROS-Patch.git}"
HERE=$(cd "$(dirname "$0")" && pwd)
DEST="${1:-$HERE/BROS-Patch}"
LAUNCHER="Bleach Rebirth of Souls Community Patch.py"

die() { printf '\nerror: %s\n' "$*" >&2; exit 1; }
case "$DEST" in /*) ;; *) DEST="$PWD/$DEST" ;; esac

echo ""
echo "  Before your first launch, copy your \"BLEACH Rebirth of Souls\" game folder"
echo "  somewhere safe. The launcher's Repair button restores from it."
echo ""

if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # A fresh Homebrew is not on this shell's PATH yet.
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$b" ]; then eval "$("$b" shellenv)"; break; fi
    done
    command -v brew >/dev/null 2>&1 || die "Homebrew did not install; see https://brew.sh"
fi

brew install git python-tk@3.13
PY="$(brew --prefix)/bin/python3.13"
"$PY" -c 'import tkinter' 2>/dev/null || die "$PY cannot load tkinter"

if [ -d "$DEST/.git" ]; then
    echo "Updating $DEST in place (your launcher settings are kept)..."
    git -C "$DEST" remote set-url origin "$REPO_URL"
    git -C "$DEST" fetch --progress origin || die "the download did not finish; run this again"
    git -C "$DEST" reset -q --hard origin/main || die "the download did not finish; run this again"
    git -C "$DEST" branch -q --set-upstream-to=origin/main 2>/dev/null || true
else
    echo "Downloading the patch into $DEST (about 1.4 GB)..."
    git clone --filter=blob:none --progress "$REPO_URL" "$DEST" ||
        die "the download did not finish; delete $DEST if it exists and run this again"
fi

echo ""
echo "Installed. Start the launcher with:"
echo "  cd \"$DEST\" && \"$PY\" \"$LAUNCHER\""
