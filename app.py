from flask import Flask, render_template
from flask_socketio import SocketIO
import subprocess
import sys
import json

app = Flask(__name__)
socketio = SocketIO(app)

@app.route('/')
def index():
    """Serves the main HTML page."""
    return render_template('index.html')

@socketio.on('run_script')
def handle_run_script(data):
    """Listens for a command from the browser to run a script."""
    script_name = data['script_name']
    
    # Determine the OS and construct the command
    if sys.platform == "win32":
        command = f"powershell.exe -ExecutionPolicy Bypass -File .\\scripts\\windows\\{script_name}"
    else: # For Linux/macOS
        command = f"./scripts/linux/{script_name}"
        
    try:
        # Run the script and capture its output
        output = subprocess.check_output(command, shell=True, text=True, stderr=subprocess.PIPE)
        # Send the successful result (which should be JSON) back to the browser
        socketio.emit('script_result', {'output': output})
    except subprocess.CalledProcessError as e:
        # Send any errors back to the browser
        error_message = f"ERROR executing {script_name}:\n{e.stderr}"
        # To maintain consistency, format the error as a JSON string
        error_json = json.dumps({
            "parameter": script_name,
            "status": "Execution Error",
            "details": e.stderr.strip()
        })
        socketio.emit('script_result', {'output': error_json})
    except Exception as e:
        error_json = json.dumps({
            "parameter": script_name,
            "status": "Application Error",
            "details": str(e)
        })
        socketio.emit('script_result', {'output': error_json})

if __name__ == '__main__':
    # Runs the web server
    # allow_unsafe_werkzeug is needed for newer versions of Flask with SocketIO
    socketio.run(app, debug=True, allow_unsafe_werkzeug=True)