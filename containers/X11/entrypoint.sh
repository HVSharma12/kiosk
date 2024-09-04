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

    # Stop all processes related to X server and icewm-session-lite
    pkill -SIGTERM -P 1  # Send SIGTERM to all processes in the current process group (started by this script)

    # Wait for processes to shut down
    sleep 5

    # Force kill remaining processes if still running
    pkill -SIGKILL -P 1  # Forcefully terminate all processes under PID 1 if they didn't stop
    log "Cleanup complete, exiting"
    exit 0
}

# Set default DISPLAY if not set
if [ -z "$DISPLAY" ]; then
    log "DISPLAY variable is not set, defaulting to :0"
    DISPLAY=:0
fi

# Clean up existing X server lock files and sockets
log "Cleaning up existing X server lock files for display $DISPLAY"
rm -f /tmp/.X${DISPLAY_NUM}-lock /tmp/.X11-unix/X${DISPLAY_NUM}

# Start X server and icewm-session-lite
log "Starting X server on display $DISPLAY"
exec startx -- "$DISPLAY"