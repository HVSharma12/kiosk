#!/bin/bash

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $@"
}

log "Starting X11 entrypoint script"

# Function to handle cleanup on SIGTERM
cleanup() {
    log "Received SIGTERM, shutting down gracefully..."
    
    # Kill all X11 and related processes
    killall Xorg icewm-session
    
    # Wait for all child processes to finish
    wait

    log "All processes terminated, exiting."
    exit 0
}

# Trap SIGTERM and call cleanup function
trap 'cleanup' SIGTERM

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
