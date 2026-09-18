#!/usr/bin/env bash
# Discover remote TCP listeners and forward them for the lifetime of Herdr.
set -eu

if [[ $# -eq 0 || $1 == --help || $1 == -h ]]; then
  echo 'Usage: herdr-forward SSH_HOST [HERDR_OPTIONS...]'
  echo 'Example: herdr-forward nixos-dev --remote-keybindings server'
  echo 'Forwards loopback/wildcard TCP listeners on ports 1024–65535 to 127.0.0.1.'
  exit 0
fi
host=$1
shift
[[ $host != -* ]] || { echo 'Expected an SSH host, not an option.' >&2; exit 2; }

umask 077
state=$(mktemp -d /tmp/herdr-forward.XXXXXX)
control=$state/ssh
log_dir=${XDG_STATE_HOME:-$HOME/.local/state}/herdr-forward
mkdir -p "$log_dir"
log=$log_dir/$(basename "$state").log
watcher=
cleanup() {
  trap - EXIT
  if [[ -n $watcher ]]; then
    kill "$watcher" 2>/dev/null || true
    wait "$watcher" 2>/dev/null || true
  fi
  ssh -S "$control" -O exit "$host" >/dev/null 2>&1 || true
  rm -rf "$state"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# Use a private master; never alter or close another application's SSH session.
ssh -fN -M -S "$control" -o ControlPersist=no \
  -o BatchMode=yes -o ConnectTimeout=10 -o ExitOnForwardFailure=yes \
  -o ClearAllForwardings=yes -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=3 "$host"

watch_ports() {
  trap - EXIT
  trap 'exit 0' INT TERM HUP
  while ssh -S "$control" -O check "$host" >/dev/null 2>&1; do
    if ! ssh -n -S "$control" -o BatchMode=yes -o ConnectTimeout=10 "$host" \
      'ss -H -ltn' > "$state/listeners" 2>> "$log"; then
      echo 'Port discovery failed; retrying.' >> "$log"
      sleep 3
      continue
    fi
    # Ignore listeners bound only to a specific LAN/Tailscale address.
    awk '{
      address=$4; port=address; sub(/^.*:/, "", port)
      sub(/:[^:]*$/, "", address)
      if (port ~ /^[0-9]+$/ && port+0 >= 1024 && port+0 <= 65535 &&
          (address == "127.0.0.1" || address == "0.0.0.0" ||
           address == "[::1]" || address == "[::]" || address == "*")) {
        destination=(address == "[::1]" || address == "[::]" ? "[::1]" : "127.0.0.1")
        # Prefer IPv4 when both address families listen on the same port.
        if (!(port in targets) || destination == "127.0.0.1") targets[port]=destination
      }
    } END { for (port in targets) print port, targets[port] }' \
      "$state/listeners" > "$state/ports"

    for active in "$state"/active-*; do
      [[ -f $active ]] || continue
      port=${active##*-}
      if ! grep -q "^$port " "$state/ports"; then
        IFS= read -r destination < "$active"
        ssh -S "$control" -O cancel -L "127.0.0.1:$port:$destination:$port" \
          "$host" >> "$log" 2>&1 || true
        rm -f "$active" "$state/warned-$port"
        echo "Stopped forwarding port $port" >> "$log"
      fi
    done
    while read -r port destination; do
      [[ ! -f $state/active-$port ]] || continue
      if ssh -n -S "$control" -O forward -o ExitOnForwardFailure=yes \
        -L "127.0.0.1:$port:$destination:$port" "$host" > "$state/error" 2>&1; then
        printf '%s\n' "$destination" > "$state/active-$port"
        rm -f "$state/warned-$port"
        echo "127.0.0.1:$port -> $host:$destination:$port" >> "$log"
      elif [[ ! -f $state/warned-$port ]]; then
        echo "Cannot forward port $port (possibly occupied); will retry." >> "$log"
        while IFS= read -r line; do printf '%s\n' "$line"; done < "$state/error" >> "$log"
        touch "$state/warned-$port"
      fi
    done < "$state/ports"
    sleep 3
  done
  echo 'SSH forwarding connection lost; restart herdr-forward to reconnect.' >> "$log"
}

watch_ports &
watcher=$!
echo "Automatic port forwarding enabled. Log: $log" >&2
herdr --remote "$host" "$@"
