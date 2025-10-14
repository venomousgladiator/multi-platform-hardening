from flask import Flask, render_template
from flask_socketio import SocketIO
import subprocess
import sys
import json
import os
import logging
from logging.handlers import RotatingFileHandler
from report_generator import generate_report


if not os.path.exists('logs'):
    os.makedirs('logs')

log_handler = RotatingFileHandler('logs/hardening_tool.log', maxBytes=100000, backupCount=5)
log_handler.setFormatter(logging.Formatter(
    '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
))
log_handler.setLevel(logging.INFO)

app = Flask(__name__)
app.logger.addHandler(log_handler)
app.logger.setLevel(logging.INFO)
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
    app.logger.info(f"Executing script: {script_name}")

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

@socketio.on('list_rollbacks')
def handle_list_rollbacks():
    """Scans the rollback directory and sends the list of files to the browser."""
    try:
        if not os.path.exists('rollback'):
            os.makedirs('rollback')
        
        files = [f for f in os.listdir('rollback') if f.endswith('.json')]
        socketio.emit('rollback_list', {'files': files})
    except Exception as e:
        socketio.emit('rollback_list', {'files': [], 'error': str(e)})
@socketio.on('generate_report')
def handle_generate_report(data):
    """Runs all 'Check' scripts and generates a PDF report."""
    app.logger.info("Starting report generation.")
    scripts_to_audit = data['scripts']
    audit_results = []
    
    for script_name in scripts_to_audit:
        try:
            if sys.platform == "win32":
                command = f"powershell.exe -ExecutionPolicy Bypass -File .\\scripts\\windows\\{script_name}"
            else:
                command = f"./scripts/linux/{script_name}"
            
            output = subprocess.check_output(command, shell=True, text=True, stderr=subprocess.PIPE)
            audit_results.append(json.loads(output))
        except Exception as e:
            audit_results.append({"parameter": script_name, "status": "Error", "details": str(e)})

    try:
        report_name = generate_report(audit_results)
        app.logger.info(f"Report generated: {report_name}")
        socketio.emit('report_generated', {'filename': report_name})
    except Exception as e:
        app.logger.error(f"Failed to generate report: {e}")
        socketio.emit('report_generated', {'error': str(e)})
        
@socketio.on('run_rollback')
def handle_run_rollback(data):
    """Executes a rollback script using a value from a rollback file."""
    filename = data['filename']
    filepath = os.path.join('rollback', filename)

    try:
        # --- FIX: Check if the file is empty before trying to read it ---
        if os.path.getsize(filepath) == 0:
            raise ValueError("Rollback file is empty. Cannot proceed.")

        with open(filepath, 'r') as f:
            rollback_data = json.load(f)
        
        value_to_restore = rollback_data.get('value')
        if value_to_restore is None:
            raise ValueError("Rollback file is missing the 'value' key.")
        
        # Determine which rollback script to use based on filename
        rollback_script_name = ""
        command = ""

        # --- WINDOWS LOGIC ---
        if "PasswordHistory" in filename:
            rollback_script_name = "Rollback-PasswordHistory.ps1"
            if sys.platform == "win32":
                command = f"powershell.exe -ExecutionPolicy Bypass -File .\\scripts\\windows\\{rollback_script_name} -RollbackValue {value_to_restore}"
        
        # --- LINUX LOGIC ---
        elif "CramfsModule" in filename:
            rollback_script_name = "Enable-CramfsModule.sh"
            if "linux" in sys.platform:
                command = f"./scripts/linux/{rollback_script_name} {value_to_restore}"

        if not command:
            raise ValueError(f"Could not determine the correct rollback script or OS for {filename}.")

        # Run the constructed command
        output = subprocess.check_output(command, shell=True, text=True, stderr=subprocess.PIPE)
        socketio.emit('script_result', {'output': output})
        
        # On success, delete the used rollback file
        os.remove(filepath)
        
    except Exception as e:
        error_json = json.dumps({"parameter": f"Rollback for {filename}", "status": "Error", "details": str(e)})
        socketio.emit('script_result', {'output': error_json})
if __name__ == '__main__':
    # Runs the web server
    # allow_unsafe_werkzeug is needed for newer versions of Flask with SocketIO
    socketio.run(app, debug=True, allow_unsafe_werkzeug=True)