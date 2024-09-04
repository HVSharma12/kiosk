#!/bin/bash

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $@"
}

log "Starting X11 entrypoint script"

# Trap signals (SIGTERM, SIGINT) for graceful shutdown
trap 'log "Received SIGTERM, shutting down"; cleanup' SIGTERM
trap 'log "Received SIGINT, shutting down"; cleanup' SIGINT

# Cleanup function to stop all relevant processes
cleanup() {
    log "Cleaning up and stopping processes"

    # Stop the X server and icewm-session-lite gracefully
    pkill -SIGTERM Xorg
    pkill -SIGTERM icewm-session-lite

    # Wait for processes to shut down
    sleep 5

    # If any processes are still running, force kill them
    if pgrep Xorg > /dev/null; then
        log "Xorg did not stop, forcing shutdown"
        pkill -SIGKILL Xorg
    fi

    if pgrep icewm-session-lite > /dev/null; then
        log "icewm-session-lite did not stop, forcing shutdown"
        pkill -SIGKILL icewm-session-lite
    fi

    log "Cleanup complete, exiting"
    exit 0
}

# Check if the DISPLAY environment variable is set
if [ -z "$DISPLAY" ]; then
    log "DISPLAY variable is not set, defaulting to :0"
    DISPLAY=:0
fi

# Extract display number from DISPLAY variable
DISPLAY_NUM=$(echo $DISPLAY | sed 's/^://')

# Clean up the specific X server lock files and sockets
log "Cleaning up existing X server lock files for display $DISPLAY"
rm -f /tmp/.X${DISPLAY_NUM}-lock /tmp/.X11-unix/X${DISPLAY_NUM}

if [ $# -gt 0 ]; then
    log "Executing custom command: $@"
    exec "$@"
else
    log "Starting X server on display $DISPLAY"
    exec startx -- "$DISPLAY"
fi
