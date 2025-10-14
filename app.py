import subprocess
import sys
import json
import platform
import os
import logging
from logging.handlers import RotatingFileHandler
import datetime
from report_generator import generate_report
import cmd
from tqdm import tqdm
from flask import Flask, render_template, send_from_directory
from flask_socketio import SocketIO

# --- 1. Setup Logging & Global Definitions ---
if not os.path.exists('logs'):
    os.makedirs('logs')
log_handler = RotatingFileHandler('logs/syswarden.log', maxBytes=100000, backupCount=5)
log_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s: %(message)s'))
logger = logging.getLogger(__name__)
logger.addHandler(log_handler)
logger.setLevel(logging.INFO)

WINDOWS_MODULES = {
    "L1": ["AccountPolicies.ps1", "LocalPolicies.ps1", "SecurityOptions.ps1"],
    "L2": ["SystemServices.ps1", "WindowsFirewall.ps1"],
    "L3": ["AdvancedAudit.ps1", "Defender.ps1"]
}
LINUX_MODULES = {
    "L1": ["Filesystem.sh", "PackageManagement.sh", "AccessControl.sh"],
    "L2": ["Services.sh", "Network.sh"],
    "L3": ["Firewall.sh", "LoggingAndAuditing.sh"]
}

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

# --- 2. Shared Core Logic ---
# This function is now used by both the CLI and the Web UI
def run_profile(level, mode, os_type, socketio_instance=None):
    logger.info(f"Starting '{mode}' process for Level {level} on {os_type}")
    
    all_results = []
    modules_to_run = []
    levels = WINDOWS_MODULES if os_type == "Windows" else LINUX_MODULES
    
    if level in ["L1", "L2", "L3"]: modules_to_run.extend(levels.get("L1", []))
    if level in ["L2", "L3"]: modules_to_run.extend(levels.get("L2", []))
    if level in ["L3"]: modules_to_run.extend(levels.get("L3", []))
    modules_to_run = sorted(list(set(modules_to_run)))
    
    total_modules = len(modules_to_run)
    
    for i, module_name in enumerate(modules_to_run):
        # Emit progress to the web UI if a socketio instance is provided
        if socketio_instance:
            socketio_instance.emit('progress_update', {'current': i + 1, 'total': total_modules, 'module': module_name})

        module_path = os.path.join('scripts', os_type.lower(), 'modules', module_name)
        if not os.path.exists(module_path):
            error_msg = f"Module file not found at '{module_path}'"
            if socketio_instance:
                socketio_instance.emit('console_output', {'status': 'Failure', 'parameter': 'System Error', 'details': error_msg})
            continue

        if os_type == "Windows":
            command = f"powershell.exe -ExecutionPolicy Bypass -File .\\{module_path} -Mode {mode} -Level {level}"
        else:
            command = f"./{module_path} {mode} {level}"
        
        try:
            process = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
            for line in process.stdout.strip().split('\n'):
                if not line: continue
                try:
                    data = json.loads(line)
                    all_results.append(data)
                    if socketio_instance:
                        socketio_instance.emit('console_output', data)
                except json.JSONDecodeError:
                    if socketio_instance:
                        socketio_instance.emit('console_output', {'status': 'Warning', 'parameter': 'RAW Output', 'details': line.strip()})
        except subprocess.CalledProcessError as e:
            error_details = f"Module '{module_name}' exited with an error. STDERR: {e.stderr.strip()}"
            if socketio_instance:
                socketio_instance.emit('console_output', {'status': 'Failure', 'parameter': f'Module Error: {module_name}', 'details': error_details})
    
    return all_results

# --- 3. Web Application (Flask & SocketIO) ---
app = Flask(__name__)
socketio = SocketIO(app)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/reports/<path:filename>')
def download_report(filename):
    return send_from_directory('reports', filename, as_attachment=True)

@socketio.on('run_action')
def handle_run_action(data):
    level = data.get('level', 'L1')
    mode = data.get('mode', 'Audit')
    os_type = platform.system()
    
    socketio.emit('action_started', {'mode': mode, 'level': level})
    results = run_profile(level, mode, os_type, socketio)
    
    if mode == 'Audit' and data.get('generate_report', False):
        if not results:
            socketio.emit('action_finished', {'status': 'Failure', 'message': 'Report generation failed: No audit data collected.'})
            return
        report_filename = generate_report(results, os_type, level)
        socketio.emit('action_finished', {'status': 'Success', 'message': 'Report generated successfully!', 'filename': os.path.basename(report_filename)})
    else:
        socketio.emit('action_finished', {'status': 'Success', 'message': f'{mode} process completed for level {level}.'})

# ... (Existing CLI code can be here, or run separately) ...
# For simplicity, we assume this file is now primarily for the web app.

if __name__ == '__main__':
    # You can run the web server with: python app.py
    # Or the CLI with: python cli.py
    print("Starting SysWarden Web UI...")
    logger.info("SysWarden Web UI started.")
    socketio.run(app, debug=True, allow_unsafe_werkzeug=True)
