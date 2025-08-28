#!/bin/sh

hyprctl dispatch killactive >/dev/null 2>&1
exit 0

# Get the class (application name) and PID of the active window.
ACTIVE_WINDOW_INFO=$(hyprctl activewindow -j)
WINDOW_CLASS=$(echo "$ACTIVE_WINDOW_INFO" | jq -r ".class")
PID=$(echo "$ACTIVE_WINDOW_INFO" | jq -r ".pid")

echo $WINDOW_CLASS
echo $PID

# Check if the class is "org.remmina.Remmina".
if [ "$WINDOW_CLASS" = "org.remmina.Remmina" ]; then
  if [ -n "$PID" ]; then
    kill "$PID"
  fi
else
  hyprctl dispatch killactive >/dev/null 2>&1
fi
