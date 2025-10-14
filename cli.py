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

# --- 1. Setup Logging & Global Definitions ---
# Establishes a consistent logging mechanism for all CLI operations.
if not os.path.exists('logs'):
    os.makedirs('logs')
log_handler = RotatingFileHandler('logs/syswarden_cli.log', maxBytes=100000, backupCount=5)
log_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s: %(message)s'))
logger = logging.getLogger(__name__)
logger.addHandler(log_handler)
logger.setLevel(logging.INFO)

# Master lists of modules the CLI will orchestrate for each OS.
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

# Color codes for professional terminal output.
class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

# --- 2. The Main Interactive Shell Class ---
class SysWardenShell(cmd.Cmd):
    """
    The main class for the interactive SysWarden shell.
    Inherits from Python's `cmd.Cmd` to create a command-loop interface.
    """
    intro = f'{bcolors.BOLD}Welcome to the SysWarden Interactive Shell. Type help or ? to list commands.\n{bcolors.ENDC}'
    prompt = f'({bcolors.OKBLUE}SysWarden{bcolors.ENDC}) > '
    os_type = platform.system()

    def __init__(self):
        super().__init__()
        logger.info("SysWarden Interactive Shell started.")
        print(f"{bcolors.HEADER}--- SysWarden CLI ---{bcolors.ENDC}")
        print(f"Detected Operating System: {bcolors.BOLD}{self.os_type}{bcolors.ENDC}")

    # --- Core Execution Engine with Progress Bar ---
    def _run_profile(self, level, mode):
        """
        The core function that orchestrates the execution of modules,
        displaying a clean progress bar instead of verbose module lists.
        """
        print(f"\n{bcolors.BOLD}Starting '{mode}' process for Level {level}...{bcolors.ENDC}")
        logger.info(f"Starting '{mode}' process for Level {level}")
        
        all_results = []
        modules_to_run = []
        levels = WINDOWS_MODULES if self.os_type == "Windows" else LINUX_MODULES
        
        # Build the list of modules based on cumulative levels (L2 includes L1, etc.)
        if level in ["L1", "L2", "L3"]: modules_to_run.extend(levels.get("L1", []))
        if level in ["L2", "L3"]: modules_to_run.extend(levels.get("L2", []))
        if level in ["L3"]: modules_to_run.extend(levels.get("L3", []))
        modules_to_run = sorted(list(set(modules_to_run))) # Remove duplicates

        # Wrap the loop with tqdm for a clean progress bar
        with tqdm(total=len(modules_to_run), desc="Overall Progress", unit="module", bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt}") as pbar:
            for module_name in modules_to_run:
                pbar.set_description(f"Executing {module_name}")
                
                module_path = os.path.join('scripts', self.os_type.lower(), 'modules', module_name)
                if not os.path.exists(module_path):
                    tqdm.write(f"  {bcolors.FAIL}ERROR:{bcolors.ENDC} Module file not found: '{module_path}'")
                    pbar.update(1)
                    continue

                if self.os_type == "Windows":
                    command = f"powershell.exe -ExecutionPolicy Bypass -File .\\{module_path} -Mode {mode} -Level {level}"
                else: # Linux
                    command = f"./{module_path} {mode} {level}"
                
                try:
                    process = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
                    for line in process.stdout.strip().split('\n'):
                        if not line: continue
                        try:
                            data = json.loads(line)
                            all_results.append(data)
                            # Only print output during 'harden' or if there's a problem during 'audit'
                            if mode == 'Harden' or data.get('status') not in ['Compliant', 'Info']:
                                status = data.get('status', 'ERROR')
                                status_color = bcolors.OKGREEN if status in ['Success', 'Compliant'] else bcolors.FAIL if status in ['Failure', 'Not Compliant'] else bcolors.OKBLUE
                                tqdm.write(f"  [{status_color}{status}{bcolors.ENDC}] {data.get('parameter', 'N/A')}: {data.get('details', 'N/A')}")
                        except json.JSONDecodeError:
                            tqdm.write(f"  {bcolors.WARNING}RAW: {line.strip()}{bcolors.ENDC}")
                except subprocess.CalledProcessError as e:
                    tqdm.write(f"  {bcolors.FAIL}MODULE ERROR:{bcolors.ENDC} Module '{module_name}' exited.")
                    tqdm.write(f"  {bcolors.FAIL}STDERR: {e.stderr.strip()}{bcolors.ENDC}")
                
                pbar.update(1) # Update the progress bar after each module
        
        return all_results

    # --- Shell Command Implementations ---
    def do_harden(self, arg):
        """Apply security policies to the system. Usage: harden <L1|L2|L3>"""
        if arg not in ['L1', 'L2', 'L3']:
            print(f"{bcolors.FAIL}Error: Please specify a valid level (L1, L2, or L3).{bcolors.ENDC}")
            return
        self._run_profile(arg, 'Harden')

    def do_audit(self, arg):
        """Check system compliance against policies. Usage: audit <L1|L2|L3>"""
        if arg not in ['L1', 'L2', 'L3']:
            print(f"{bcolors.FAIL}Error: Please specify a valid level (L1, L2, or L3).{bcolors.ENDC}")
            return
        results = self._run_profile(arg, 'Audit')
        print(f"\n{bcolors.BOLD}Audit complete.{bcolors.ENDC} Found {sum(1 for r in results if r.get('status') == 'Not Compliant')} non-compliant items.")

    def do_report(self, arg):
        """Run an audit and generate a PDF report. Usage: report <L1|L2|L3>"""
        if arg not in ['L1', 'L2', 'L3']:
            print(f"{bcolors.FAIL}Error: Please specify a level for the report (L1, L2, or L3).{bcolors.ENDC}")
            return
        
        results = self._run_profile(arg, 'Audit')
        if not results:
            print(f"{bcolors.FAIL}Report generation failed: No audit data was collected.{bcolors.ENDC}")
            return
        
        print(f"\n{bcolors.BOLD}Generating PDF report for level {arg}...{bcolors.ENDC}")
        report_filename = generate_report(results, self.os_type, arg)
        print(f"{bcolors.OKGREEN}Report successfully generated: {report_filename}{bcolors.ENDC}")

    def do_rollbacks(self, arg):
        """List available rollback files. Usage: rollbacks"""
        print(f"\n{bcolors.HEADER}--- Available Rollback Files ---{bcolors.ENDC}")
        rollback_dir = 'rollback'
        if not os.path.exists(rollback_dir) or not os.listdir(rollback_dir):
            print("No rollback files found.")
            return
        files = sorted([f for f in os.listdir(rollback_dir) if f.endswith(".json")], reverse=True)
        for filename in files:
            print(f"  - {filename}")
    
    def do_rollback(self, arg):
        """Revert changes using a specific rollback file. Usage: rollback <filename>"""
        filename = arg.strip()
        if not filename:
            print(f"{bcolors.FAIL}Error: Please specify a rollback filename.{bcolors.ENDC}")
            return
        
        # This is the corrected logic using an absolute path.
        rollback_path = os.path.abspath(os.path.join('rollback', filename))
        
        if not os.path.exists(rollback_path):
            print(f"{bcolors.FAIL}Error: Rollback file '{filename}' not found.{bcolors.ENDC}")
            return

        try:
            module_base_name = filename.split('_', 1)[1].replace('.json', '')
        except IndexError:
            print(f"{bcolors.FAIL}Error: Invalid rollback file format. Expected 'TIMESTAMP_ModuleName.json'.{bcolors.ENDC}")
            return

        if self.os_type == "Windows":
            module_name = f"{module_base_name}.ps1"
            module_path = os.path.join('scripts', 'windows', 'modules', module_name)
            command = f"powershell.exe -ExecutionPolicy Bypass -File .\\{module_path} -Mode Rollback -RollbackFile '{rollback_path}'"
        else: # Linux
            module_name = f"{module_base_name}.sh"
            module_path = os.path.join('scripts', 'linux', 'modules', module_name)
            command = f"./{module_path} Rollback '{rollback_path}'"
        
        print(f"Executing rollback for {filename} using module {module_name}...")
        try:
            process = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
            for line in process.stdout.strip().split('\n'):
                 if not line: continue
                 print(f"  {bcolors.OKGREEN}{line.strip()}{bcolors.ENDC}")
            print(f"{bcolors.OKGREEN}Rollback completed successfully.{bcolors.ENDC}")
            os.remove(rollback_path)
            print(f"{bcolors.OKBLUE}Deleted used rollback file: {filename}{bcolors.ENDC}")
        except subprocess.CalledProcessError as e:
            print(f"  {bcolors.FAIL}ROLLBACK FAILED:{bcolors.ENDC} {e.stderr.strip()}")

    def do_cleanup_rollbacks(self, arg):
        """Deletes old rollback files. Usage: cleanup_rollbacks <all | #_of_days>"""
        if not arg or (arg != 'all' and not arg.isdigit()):
            print(f"{bcolors.FAIL}Usage: cleanup_rollbacks <all | number_of_days>{bcolors.ENDC}")
            return
        
        rollback_dir = 'rollback'
        if not os.path.exists(rollback_dir): return
        
        now = datetime.datetime.now()
        count = 0
        for filename in os.listdir(rollback_dir):
            filepath = os.path.join(rollback_dir, filename)
            if arg == 'all':
                os.remove(filepath)
                count += 1
            else:
                try:
                    file_time = os.path.getmtime(filepath)
                    age = now - datetime.datetime.fromtimestamp(file_time)
                    if age.days >= int(arg):
                        os.remove(filepath)
                        count += 1
                except (ValueError, FileNotFoundError): continue
        print(f"{bcolors.OKGREEN}Cleanup complete. Deleted {count} rollback file(s).{bcolors.ENDC}")

    def do_exit(self, arg):
        """Exit the SysWarden shell."""
        print("Exiting SysWarden.")
        return True

    def emptyline(self):
        """Do nothing when an empty line is entered."""
        pass

# --- Main Execution Block ---
if __name__ == '__main__':
    # On Linux, check for root privileges before starting.
    if platform.system() == "Linux" and os.geteuid() != 0:
        print(f"{bcolors.FAIL}Error: This script must be run with sudo on Linux.{bcolors.ENDC}")
        sys.exit(1)
    
    try:
        SysWardenShell().cmdloop()
    except KeyboardInterrupt:
        print("\nExiting SysWarden.")

