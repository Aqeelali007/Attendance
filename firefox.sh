#!/bin/bash

LOGFILE="/tmp/chromium-startup.log"
PORTS=(9222 9223 9224 9225 9226)
CHROMIUM_BINARY="/usr/bin/chromium-browser"

# Ensure Xvfb and Chromium are installed
if ! command -v Xvfb &> /dev/null
then
    echo "$(date): Xvfb is not installed. Please install it and rerun the script." | tee -a $LOGFILE
    exit 1
fi

if [ ! -x "$CHROMIUM_BINARY" ]; then
    echo "$(date): Chromium is not installed at $CHROMIUM_BINARY. Please install it and rerun the script." | tee -a $LOGFILE
    exit 1
fi

# Function to start Xvfb and Chromium on a specific port
start_chromium_with_xvfb() {
    local port=$1
    local display=$2

    # Start Xvfb for this Chromium instance
    echo "$(date): Starting Xvfb on display :$display" | tee -a $LOGFILE
    nohup Xvfb :$display -ac > "/tmp/xvfb-$display.log" 2>&1 &
    export DISPLAY=:$display

    # Ensure Xvfb starts correctly
    sleep 2

    # Check if Xvfb is running
    if ! pgrep -f "Xvfb :$display" > /dev/null; then
        echo "$(date): Failed to start Xvfb on display :$display" | tee -a $LOGFILE
        return
    fi

    # Check if Chromium is already running on this port
    echo "$(date): Checking for Chromium instance on port $port" | tee -a $LOGFILE
    if pgrep -f "$CHROMIUM_BINARY --headless --remote-debugging-port=$port" > /dev/null; then
        echo "$(date): Chromium on port $port is already running. Skipping." | tee -a $LOGFILE
        return
    else
        echo "$(date): No Chromium instance on port $port found. Starting Chromium." | tee -a $LOGFILE
    fi

    # Start Chromium in headless mode with the specified port
    nohup $CHROMIUM_BINARY --headless --no-sandbox --disable-gpu --disable-software-rasterizer --disable-dbus --remote-debugging-port=$port >> "/tmp/chromium-$port.log" 2>&1 &

    disown

    # Log the PID of the Chromium process
    echo "$(date): Chromium started on port $port with PID $!" | tee -a $LOGFILE
}

# Start separate Xvfb and Chromium instances for each port
for i in "${!PORTS[@]}"; do
    port=${PORTS[$i]}
    display=$((99 + i)) # Use a unique display number for each instance
    start_chromium_with_xvfb $port $display
    sleep 2 # Optional: Small delay to stagger starts
done

# Prevent the script from exiting (keep it alive for pm2)
tail -f /dev/null