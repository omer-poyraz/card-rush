#!/usr/bin/env bash
# Locates the Godot 4.7.x editor binary. Override with GODOT=/path/to/godot.
if [ -n "$GODOT" ] && [ -x "$GODOT" ]; then echo "$GODOT"; exit 0; fi
for c in godot4 godot "$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64" /usr/local/bin/godot; do
  if command -v "$c" >/dev/null 2>&1; then command -v "$c"; exit 0; fi
  if [ -x "$c" ]; then echo "$c"; exit 0; fi
done
echo "Godot 4.7 not found. Set GODOT=/path/to/Godot_v4.7.2" >&2
exit 1
