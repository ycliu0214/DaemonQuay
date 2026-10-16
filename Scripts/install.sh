#!/bin/zsh
set -euo pipefail
HERE="${0:A:h}"
BASE="$HOME/.local/share/DaemonQuay"
OLD="$HOME/.local/share/ServiceDeck"
# Migration is non-destructive: copy user preferences once, never remove the old tree.
# Stop old GUI-managed jobs before running this installer.
for id in omlx caddy; do
  if /bin/launchctl print "gui/$(id -u)/dev.servicedeck.$id" 2>/dev/null | /usr/bin/grep -q 'pid = '; then
    echo "Stop old ServiceDeck-managed $id before installing DaemonQuay." >&2
    exit 1
  fi
done
mkdir -p "$BASE/logs" "$BASE/agents" "$BASE/modules"
if [[ -d "$OLD" ]]; then
  for f in settings.json enabled-modules.json service-order.json; do
    if [[ -f "$OLD/$f" && ! -e "$BASE/$f" ]]; then
      cp "$OLD/$f" "$BASE/$f"
      echo "Migrated $f from ServiceDeck (original retained)"
    fi
  done
fi
if [[ ! -f "$BASE/settings.json" ]]; then
  cp "$HERE/../Config/settings.json" "$BASE/settings.json"
  echo "Created $BASE/settings.json"
else
  echo "Retained existing $BASE/settings.json"
fi
if [[ ! -f "$BASE/enabled-modules.json" ]]; then
  printf '["omlx", "caddy"]\n' > "$BASE/enabled-modules.json"
  echo "Enabled bundled oMLX and Caddy modules"
fi
echo "No service launched. No Python or external service-controller installed."
