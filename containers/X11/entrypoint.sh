#!/bin/bash

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $@"
}

log "Starting X11 entrypoint script"

# Trap signals (SIGTERM, SIGINT) for graceful shutdown
trap 'log "Received SIGTERM, initiating shutdown"; cleanup' SIGTERM
trap 'log "Received SIGINT, initiating shutdown"; cleanup' SIGINT

# Cleanup function to stop all relevant processes
cleanup() {
    log "Cleaning up and stopping processes"

    # Stop all processes related to X server and icewm-session-lite gracefully
    pkill -SIGTERM Xorg
    pkill -SIGTERM icewm-session-lite

    log "Cleanup complete, exiting"
    exit 0
}

# Set default DISPLAY if not set
if [ -z "$DISPLAY" ]; then
    log "DISPLAY variable is not set, defaulting to :0"
    DISPLAY=:0
fi

# Extract display number from DISPLAY variable
DISPLAY_NUM=$(echo $DISPLAY | sed 's/^://')

# Clean up existing X server lock files and sockets
log "Cleaning up existing X server lock files for display $DISPLAY"
rm -f /tmp/.X${DISPLAY_NUM}-lock /tmp/.X11-unix/X${DISPLAY_NUM}

# If a custom command is passed, run it
if [ $# -gt 0 ]; then
    log "Executing custom command: $@"
    exec "$@"
else
    # Start X server
    log "Starting X server on display $DISPLAY"
    startx -- "$DISPLAY" &
    X_PID=$!

    # Wait for X server process (Xorg) to finish
    log "X server (startx) running with PID $X_PID"
    wait $X_PID

    log "X server has exited"
fi