#!/bin/sh
# Clive (CliveCode) installer -- https://github.com/cjguarino/clive
#
#   curl -fsSL https://raw.githubusercontent.com/cjguarino/clive/main/install.sh | sh
#
# What it does, in order:
#   1. checks for python3 (the only requirement)
#   2. puts the repo in ~/.clive        (CLIVE_HOME=... to change)
#   3. links ~/.local/bin/clive        (CLIVE_BIN=... to change)
#   4. runs `clive install`, which backs up and edits ~/.claude/settings.json
#      (CLIVE_NO_WIRE=1 to skip step 4 and wire it yourself)
#
# POSIX sh on purpose: this runs piped into whatever /bin/sh is.
set -eu

REPO="${CLIVE_REPO:-cjguarino/clive}"
REF="${CLIVE_REF:-main}"
GIT_URL="${CLIVE_GIT_URL:-https://github.com/$REPO.git}"   # override for forks/SSH/testing
CLIVE_HOME="${CLIVE_HOME:-$HOME/.clive}"
CLIVE_BIN="${CLIVE_BIN:-$HOME/.local/bin}"

say()  { printf '%s\n' "$*"; }
step() { printf '==> %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- 1. requirements ------------------------------------------------------
PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
        if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
            PYTHON="$candidate"
            break
        fi
    fi
done
[ -n "$PYTHON" ] || die "python3 >= 3.8 is required.
  macOS:  xcode-select --install
  debian: sudo apt install python3"
step "python: $(command -v "$PYTHON") ($("$PYTHON" -c 'import sys;print(".".join(map(str,sys.version_info[:3])))'))"

# --- 2. fetch -------------------------------------------------------------
if [ -d "$CLIVE_HOME/.git" ] && command -v git >/dev/null 2>&1; then
    step "updating $CLIVE_HOME"
    git -C "$CLIVE_HOME" fetch --quiet origin "$REF"
    git -C "$CLIVE_HOME" checkout --quiet "$REF"
    git -C "$CLIVE_HOME" reset --hard --quiet "origin/$REF" 2>/dev/null || true
elif command -v git >/dev/null 2>&1; then
    step "cloning $REPO into $CLIVE_HOME"
    [ -e "$CLIVE_HOME" ] && [ ! -d "$CLIVE_HOME/.git" ] && \
        die "$CLIVE_HOME exists and is not a clive checkout; move it or set CLIVE_HOME"
    git clone --quiet --depth 1 --branch "$REF" \
        "$GIT_URL" "$CLIVE_HOME"
else
    # No git: fall back to a tarball. Works, but `clive upgrade` won't.
    step "downloading $REPO@$REF (no git found)"
    command -v curl >/dev/null 2>&1 || die "need git or curl"
    tmp="$(mktemp -d)"
    curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | \
        tar -xzf - -C "$tmp" || die "download failed"
    src="$(find "$tmp" -maxdepth 1 -type d -name 'clive-*' | head -1)"
    [ -n "$src" ] || die "unexpected archive layout"
    mkdir -p "$CLIVE_HOME"
    cp -R "$src"/. "$CLIVE_HOME"/
    rm -rf "$tmp"
fi

[ -f "$CLIVE_HOME/bin/clive" ] || die "$CLIVE_HOME/bin/clive missing after fetch"
chmod +x "$CLIVE_HOME/bin/clive"

# --- 3. link onto PATH ----------------------------------------------------
mkdir -p "$CLIVE_BIN"
ln -sf "$CLIVE_HOME/bin/clive" "$CLIVE_BIN/clive"
step "linked $CLIVE_BIN/clive"

case ":$PATH:" in
    *":$CLIVE_BIN:"*) ;;
    *) say ""
       say "note: $CLIVE_BIN is not on your PATH. Add this to your shell rc:"
       say "    export PATH=\"$CLIVE_BIN:\$PATH\""
       say "" ;;
esac

# --- 4. wire into Claude Code --------------------------------------------
if [ "${CLIVE_NO_WIRE:-0}" = "1" ]; then
    say ""
    say "skipped settings.json (CLIVE_NO_WIRE=1). When ready:  clive install"
else
    say ""
    "$CLIVE_HOME/bin/clive" install
fi

say ""
say "done. clive status / clive demo / clive config"
