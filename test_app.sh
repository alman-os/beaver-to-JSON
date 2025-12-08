#!/bin/bash
# Quick test to verify the app runs and opens browser
echo "Testing app for 5 seconds..."
python app.py &
APP_PID=$!
sleep 5
kill $APP_PID 2>/dev/null
echo "Test complete. If a browser window opened, the fix is working!"
