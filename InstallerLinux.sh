#!/bin/sh
# ReBalance of Souls -- Linux installer (Steam Deck, Bazzite, Ubuntu, Fedora,
# Arch, ...)
#
#   sh InstallerLinux.sh             install into BROS-Patch/ next to this file
#   sh InstallerLinux.sh <folder>    install into <folder> instead
#
# The launcher needs git and Python 3.8+ with tkinter.
#
#   - It uses the git and Python the system already has, and installs nothing
#     with a package manager: SteamOS, Bazzite and Silverblue have a read-only
#     system, and nothing here needs root anyway.
#   - When Python has no tkinter -- Fedora-based systems such as Bazzite ship
#     it as a separate package, which a read-only system cannot simply add --
#     it downloads a private Python that has it, into your home folder.
#     Nothing outside that folder changes.
#   - It downloads the current patch files only, not the full history of every
#     file, which is about half the download.
#   - Run it again at any time: it updates the folder in place, downloads only
#     what changed, and keeps the launcher's settings (Json/config.json).
#
# It also finds the game in your Steam library so the launcher does not have to
# ask for it, and adds "ReBalance of Souls" to your applications menu.
#
# POSIX sh, not bash, so it runs the same everywhere.

set -eu

REPO_URL="${BROS_REPO_URL:-https://github.com/reBalance-Of-Souls/BROS-Patch.git}"
HERE=$(cd "$(dirname "$0")" && pwd)
DEST="${1:-$HERE/BROS-Patch}"
LAUNCHER="Bleach Rebirth of Souls Community Patch.py"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
# The private Python and the start script live here, outside DEST: the launcher
# runs "git clean" on DEST every time it starts, which would delete them.
APPDIR="$DATA/rebalance-of-souls"

say()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf '\nerror: %s\n' "$*" >&2; exit 1; }
# Quote a string for a generated shell script.
shq()  { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

[ "$(uname -s)" = Linux ] || die "this installer is for Linux (on Windows, run InstallerWindows.bat)"
case "$DEST" in /*) ;; *) DEST="$PWD/$DEST" ;; esac

say ""
say "  ReBalance of Souls - installer"
say "  =============================="
say ""
say "  Before your first launch, copy your \"BLEACH Rebirth of Souls\" game folder"
say "  somewhere safe. The launcher's Repair button restores from it."
say ""

# --- git ---------------------------------------------------------------------
git_hint() {
    OS_ID=""; OS_LIKE=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        OS_ID=$(. /etc/os-release && printf '%s' "${ID:-}")
        # shellcheck disable=SC1091
        OS_LIKE=$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")
    fi
    if [ -e /run/ostree-booted ]; then
        say "  rpm-ostree install git     (then restart the computer)"
        return
    fi
    case " $OS_ID $OS_LIKE " in
        *" debian "*|*" ubuntu "*) say "  sudo apt install git" ;;
        *" fedora "*|*" rhel "*)   say "  sudo dnf install git" ;;
        *" arch "*)                say "  sudo pacman -S git" ;;
        *suse*)                    say "  sudo zypper install git" ;;
        *)                         say "  (install the \"git\" package of your distribution)" ;;
    esac
}

if ! command -v git >/dev/null 2>&1; then
    say "git is not installed. Install it, then run this installer again:"
    git_hint
    exit 1
fi
say "git:    $(command -v git)"

# --- Python with tkinter -----------------------------------------------------
py_ok() {   # true when $1 is Python 3.8 or newer with tkinter
    "$1" -c 'import sys, tkinter; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1
}

fetch_python() {
    # A python-build-standalone build: a complete Python, tkinter included,
    # that runs from any folder. The same builds uv and rye install.
    command -v curl >/dev/null 2>&1 || die "curl is needed to download Python"
    case $(uname -m) in
        x86_64|amd64)  triple=x86_64-unknown-linux-gnu ;;
        aarch64|arm64) triple=aarch64-unknown-linux-gnu ;;
        *) die "no private Python is available for $(uname -m): install python3 with tkinter from your distribution" ;;
    esac
    releases=https://github.com/astral-sh/python-build-standalone/releases
    tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$releases/latest") || die "cannot reach GitHub"
    tag=${tag##*/}
    # SHA256SUMS lists every build of the release, so it gives both the exact
    # file name and the checksum to verify it against.
    line=$(curl -fsSL "$releases/download/$tag/SHA256SUMS" |
           grep -E "  cpython-3\.13\.[0-9]+\+$tag-$triple-install_only\.tar\.gz\$" | head -n 1) || true
    [ -n "$line" ] || die "no Python 3.13 build for $triple in release $tag"
    sum=${line%% *}
    name=${line##* }
    tmp="$APPDIR/download.tmp"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    curl -fL --progress-bar -o "$tmp/$name" \
         "$releases/download/$tag/$(printf '%s' "$name" | sed 's/+/%2B/g')" || die "the Python download failed"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$sum" "$tmp/$name" | sha256sum -c - >/dev/null 2>&1 ||
            die "the downloaded Python is damaged (checksum mismatch); run this installer again"
    fi
    tar -xzf "$tmp/$name" -C "$tmp" || die "could not unpack the downloaded Python"
    rm -rf "$APPDIR/python"
    mv "$tmp/python" "$APPDIR/python"
    rm -rf "$tmp"
}

PY=""
for cand in python3 python; do
    p=$(command -v "$cand" 2>/dev/null) || continue
    if py_ok "$p"; then PY=$p; break; fi
done
if [ -z "$PY" ] && py_ok "$APPDIR/python/bin/python3"; then
    PY="$APPDIR/python/bin/python3"          # downloaded by an earlier run
fi
if [ -z "$PY" ]; then
    say "This system's Python has no tkinter, which the launcher needs."
    say "Downloading a private Python into $APPDIR/python (about 75 MB)..."
    mkdir -p "$APPDIR"
    fetch_python
    py_ok "$APPDIR/python/bin/python3" || die "the downloaded Python cannot load tkinter"
    PY="$APPDIR/python/bin/python3"
fi
say "Python: $PY"

# --- the patch ---------------------------------------------------------------
if [ -d "$DEST/.git" ]; then
    say ""
    say "BROS-Patch is already there: updating it in place. Your launcher"
    say "settings are kept."
    say ""
    git -C "$DEST" remote set-url origin "$REPO_URL" 2>/dev/null ||
        git -C "$DEST" remote add origin "$REPO_URL"
    git -C "$DEST" fetch --progress origin ||
        die "the download did not finish; check your connection and run this installer again"
    git -C "$DEST" reset -q --hard origin/main ||
        die "the download did not finish; check your connection and run this installer again"
    # The launcher runs "git pull", which needs the branch to follow origin/main.
    git -C "$DEST" branch -q --set-upstream-to=origin/main 2>/dev/null || true
elif [ -d "$DEST" ] && [ -n "$(ls -A "$DEST")" ]; then
    # Not a git download -- copied by hand, or left by an installer that was
    # stopped halfway. Make it one in place: a file of the patch that is
    # already there is replaced, anything else in the folder is left alone.
    say ""
    say "$DEST exists but was not downloaded with git: turning it"
    say "into a proper download in place. About 1.4 GB."
    say ""
    git -C "$DEST" init -q
    git -C "$DEST" remote add origin "$REPO_URL" 2>/dev/null ||
        git -C "$DEST" remote set-url origin "$REPO_URL"
    git -C "$DEST" fetch --filter=blob:none --progress origin ||
        die "the download did not finish; check your connection and run this installer again"
    git -C "$DEST" checkout -q -f -B main --track origin/main ||
        die "the download did not finish; check your connection and run this installer again"
else
    say ""
    say "Downloading the patch into $DEST"
    say "About 1.4 GB. If it gets interrupted, run this installer again."
    say ""
    git clone --filter=blob:none --progress "$REPO_URL" "$DEST" ||
        die "the download did not finish; check your connection and run this installer again"
fi
say ""
say "Patch:  $DEST"

# --- the game ----------------------------------------------------------------
# Steam keeps its library list in libraryfolders.vdf. The launcher's file picker
# hides folders starting with a dot, and ~/.local is one, so finding the game
# here saves every player a hunt for it.
find_game() {
    for root in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/root" \
                "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
                "$HOME/snap/steam/common/.local/share/Steam"; do
        vdf="$root/steamapps/libraryfolders.vdf"
        [ -r "$vdf" ] || continue
        { printf '%s\n' "$root"
          sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$vdf"; } |
        while IFS= read -r lib; do
            game="$lib/steamapps/common/BLEACH Rebirth of Souls"
            if [ -f "$game/BLEACH_Rebirth_of_Souls.exe" ]; then printf '%s\n' "$game"; fi
        done
    done | head -n 1
}

GAME=$(find_game || true)
if [ -n "$GAME" ]; then
    say "Game:   $GAME"
    # Only fills GAME_PATH when the launcher has none yet.
    "$PY" - "$DEST/Json/configTemplate.json" "$DEST/Json/config.json" "$GAME" <<'PYEOF' ||
import json, os, sys
template, config, game = sys.argv[1:4]
with open(config if os.path.exists(config) else template, encoding="utf-8") as f:
    settings = json.load(f)
if not settings.get("GAME_PATH"):
    settings["GAME_PATH"] = game
    with open(config, "w", encoding="utf-8") as f:
        json.dump(settings, f)
PYEOF
        warn "could not write the game folder into the launcher's settings; it will ask for it"
else
    warn "the game was not found in your Steam library. The launcher will ask for"
    warn "BLEACH_Rebirth_of_Souls.exe, in steamapps/common/BLEACH Rebirth of Souls."
fi

# --- menu entry --------------------------------------------------------------
mkdir -p "$APPDIR" "$DATA/applications"
START="$APPDIR/start-launcher.sh"
{
    printf '#!/bin/sh\n'
    printf '# Written by InstallerLinux.sh. Run the installer again rather than editing it.\n'
    printf 'cd %s || exit 1\n' "$(shq "$DEST")"
    printf 'exec %s %s "$@"\n' "$(shq "$PY")" "$(shq "$LAUNCHER")"
} > "$START"
chmod 755 "$START"

# Terminal=true: the launcher prints its progress, and its errors, to a console.
cat > "$DATA/applications/rebalance-of-souls.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ReBalance of Souls
Comment=Bleach Rebirth of Souls community patch launcher
Exec="$START"
Path=$DEST
Icon=$DEST/ressources/pimplin.ico
Terminal=true
Categories=Game;
EOF
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DATA/applications" >/dev/null 2>&1 || true
fi

say ""
say "Installed. Start \"ReBalance of Souls\" from your applications menu, or run:"
say "  $START"
say "Steam Deck Game Mode: in Desktop Mode, Steam > Add a Non-Steam Game >"
say "Browse, and pick that file."
cat <<'EOF'

One more step, once, in Steam: right-click BLEACH Rebirth of Souls >
Properties > General > Launch Options, and paste this line:

  WINEDLLOVERRIDES="dinput8=n,b" bash -c 'exec "${@/start_protected_game.exe/BLEACH_Rebirth_of_Souls.exe}"' -- %command%

It makes Proton load the patch's dinput8.dll, and start the game the way the
launcher does on Windows: without the anti-cheat bootstrapper, which blocks
that DLL.
EOF
