#!/bin/bash
# Stop all Besu nodes

echo "Stopping Besu network..."

if [ -f "besu-data/pids.txt" ]; then
    while read pid; do
        if ps -p $pid > /dev/null 2>&1; then
            echo "  Stopping process $pid..."
            kill $pid
        fi
    done < besu-data/pids.txt
    rm besu-data/pids.txt
    echo "All nodes stopped."
else
    echo "No PID file found. Searching for Besu processes..."
    pkill -f "besu --genesis-file" && echo "Besu processes stopped." || echo "No Besu processes found."
fi
