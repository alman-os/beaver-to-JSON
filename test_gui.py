#!/usr/bin/env python3
"""
Quick test to verify pywebview GUI works
Run this to test the embedded browser window before building the .app
"""
import threading
import time
from flask import Flask
import webview

# Create a minimal Flask app
app = Flask(__name__)

@app.route('/')
def home():
    return '''
    <html>
    <head><title>Test</title></head>
    <body style="font-family: Arial; padding: 50px; text-align: center;">
        <h1 style="color: green;">✓ pywebview GUI is working!</h1>
        <p>If you see this in a desktop window (not a browser), the setup is correct.</p>
        <p>Close this window to exit.</p>
    </body>
    </html>
    '''

def start_server():
    app.run(port=5050, debug=False, use_reloader=False)

if __name__ == '__main__':
    # Start Flask in background
    threading.Thread(target=start_server, daemon=True).start()

    # Give Flask a moment to start
    time.sleep(1)

    # Create GUI window
    webview.create_window('Test GUI', 'http://127.0.0.1:5050', width=600, height=400)
    webview.start()
