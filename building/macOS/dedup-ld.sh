#!/bin/bash
# dedup-ld: drop explicit .o args that are already listed in a -filelist, then call the
# real classic linker. Works around CMake's Xcode+ISPC generator double-listing the same
# object (filelist + explicit arg), which macOS 26's linker rejects as duplicate symbols.
real_ld="$(xcrun -f ld-classic 2>/dev/null)"; [ -x "$real_ld" ] || real_ld="/usr/bin/ld"
fl_objs=""; prev=""
for a in "$@"; do [ "$prev" = "-filelist" ] && fl_objs="$fl_objs
$(cat "$a" 2>/dev/null)"; prev="$a"; done
args=()
for a in "$@"; do
  case "$a" in
    *.o)
      if printf '%s\n' "$fl_objs" | grep -qxF -- "$a"; then : ; else args+=("$a"); fi ;;
    *) args+=("$a") ;;
  esac
done
exec "$real_ld" "${args[@]}"
