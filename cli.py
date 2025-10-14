import subprocess
import sys
import json
import argparse
import platform
import os
import logging
from logging.handlers import RotatingFileHandler
import datetime

# --- 1. Setup Logging ---
if not os.path.exists('logs'):
    os.makedirs('logs')
log_handler = RotatingFileHandler('logs/syswarden_cli.log', maxBytes=100000, backupCount=5)
log_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s: %(message)s'))
logger = logging.getLogger(__name__)
logger.addHandler(log_handler)
logger.setLevel(logging.INFO)

# --- 2. Define Hardening Modules ---
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

# --- 3. CLI Core Engine ---
class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def run_profile(modules, level, os_type, mode):
    """Executes a list of modules in either 'Harden' or 'Audit' mode."""
    print(f"\n{bcolors.BOLD}Starting '{mode}' process for Level {level}...{bcolors.ENDC}")
    
    for i, module_name in enumerate(modules):
        print(f"\n[{i+1}/{len(modules)}] {bcolors.HEADER}--- Executing Module: {module_name} ---{bcolors.ENDC}")
        logger.info(f"Executing module: {module_name} for Level {level} in {mode} mode.")
        
        if os_type == "Windows":
            command = f"powershell.exe -ExecutionPolicy Bypass -File .\\scripts\\windows\\modules\\{module_name} -Mode {mode} -Level {level}"
        else:
            command = f"./scripts/linux/modules/{module_name} {mode} {level}"
        
        try:
            process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            for line in process.stdout:
                try:
                    data = json.loads(line)
                    status = data.get('status', 'ERROR')
                    if status in ['Success', 'Compliant']: status_color = bcolors.OKGREEN
                    elif status in ['Failure', 'Not Compliant']: status_color = bcolors.FAIL
                    else: status_color = bcolors.OKBLUE
                    
                    details = data.get('details', 'No details provided.')
                    parameter = data.get('parameter', 'Unknown Parameter')
                    print(f"  [{status_color}{status}{bcolors.ENDC}] {parameter}: {details}")
                    logger.info(f"[{status}] {parameter}: {details}")
                except (json.JSONDecodeError, KeyError):
                    print(f"  {bcolors.WARNING}RAW: {line.strip()}{bcolors.ENDC}")

            stderr = process.communicate()[1]
            if process.returncode != 0:
                print(f"  {bcolors.FAIL}MODULE ERROR:{bcolors.ENDC} Module '{module_name}' exited with a non-zero status.")
                print(f"  {bcolors.FAIL}STDERR: {stderr.strip()}{bcolors.ENDC}")
                logger.error(f"Module '{module_name}' exited with error: {stderr.strip()}")

        except Exception as e:
            print(f"  {bcolors.FAIL}FATAL ERROR:{bcolors.ENDC} Could not execute module {module_name}. Error: {e}")
            logger.critical(f"FATAL ERROR executing {module_name}: {e}")

def list_rollbacks():
    print(f"{bcolors.HEADER}--- Available Rollback Files ---{bcolors.ENDC}")
    rollback_dir = 'rollback'
    if not os.path.exists(rollback_dir) or not os.listdir(rollback_dir):
        print("No rollback files found.")
        return

    files = sorted([f for f in os.listdir(rollback_dir) if f.endswith(".json")], reverse=True)
    for filename in files:
        print(f"  - {filename}")
    print(f"\nUse 'syswarden rollback --file <filename>' to revert changes.")

def run_rollback(filename):
    print(f"\n{bcolors.BOLD}Executing rollback for file: {filename}...{bcolors.ENDC}")
    logger.info(f"Initiating rollback for {filename}")
    
    if "_" not in filename or "." not in filename:
        print(f"{bcolors.FAIL}Error: Invalid rollback file name format. Expected 'timestamp_ModuleName.json'.{bcolors.ENDC}")
        return
        
    module_name_base = filename.split('_', 1)[1].split('.')[0]
    os_type = platform.system()
    rollback_filepath = os.path.join('rollback', filename)

    if os_type == "Windows":
        module_script = f"{module_name_base}.ps1"
        command = f"powershell.exe -ExecutionPolicy Bypass -File .\\scripts\\windows\\modules\\{module_script} -Mode Rollback -RollbackFile {rollback_filepath}"
    elif os_type == "Linux":
        module_script = f"{module_name_base}.sh"
        command = f"./scripts/linux/modules/{module_script} Rollback {rollback_filepath}"
    else:
        print(f"{bcolors.FAIL}Error: Unsupported OS for rollback.{bcolors.ENDC}")
        return
    
    # Re-use the run_profile logic for execution and streaming output
    print(f"Invoking rollback for module: {module_script}")
    run_profile([module_script], "N/A", os_type, "Rollback")
    print(f"{bcolors.OKGREEN}Rollback process completed for {filename}. Check logs for details.{bcolors.ENDC}")

def main():
    parser = argparse.ArgumentParser(
        prog="syswarden",
        description="SysWarden: An automated CLI for hardening Windows and Linux systems.",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog="""\
Usage Examples:
  syswarden harden --level L1             # Apply Level 1 hardening policies.
  syswarden audit --level L3              # Check system compliance against all L1, L2, and L3 policies.
  syswarden list-rollbacks                # Show available rollback files.
  syswarden rollback --file <filename>    # Revert changes using a specific rollback file.
"""
    )
    subparsers = parser.add_subparsers(dest="action", required=True, metavar="COMMAND")

    parser_harden = subparsers.add_parser("harden", help="Apply security policies to the system.")
    parser_harden.add_argument("--level", choices=['L1', 'L2', 'L3'], required=True, help="Hardening level (L2 includes L1, L3 includes L1 & L2).")

    parser_audit = subparsers.add_parser("audit", help="Check system compliance without making changes.")
    parser_audit.add_argument("--level", choices=['L1', 'L2', 'L3'], required=True, help="Compliance level to audit against.")
    
    subparsers.add_parser("list-rollbacks", help="List all available rollback files.")

    parser_rollback = subparsers.add_parser("rollback", help="Revert changes using a specific rollback file.")
    parser_rollback.add_argument("--file", required=True, help="The exact name of the rollback file to use (e.g., '20251015-021500_AccountPolicies.json').")

    args = parser.parse_args()
    os_type = platform.system()
    
    print(f"{bcolors.HEADER}--- SysWarden CLI ---{bcolors.ENDC}")
    logger.info(f"SysWarden CLI initiated for {os_type} with action '{args.action}'.")

    if args.action in ['harden', 'audit']:
        mode = "Harden" if args.action == 'harden' else "Audit"
        modules_to_run = []
        levels = WINDOWS_MODULES if os_type == "Windows" else LINUX_MODULES
        
        if args.level in ["L1", "L2", "L3"]: modules_to_run.extend(levels["L1"])
        if args.level in ["L2", "L3"]: modules_to_run.extend(levels["L2"])
        if args.level in ["L3"]: modules_to_run.extend(levels["L3"])
        
        run_profile(list(dict.fromkeys(modules_to_run)), args.level, os_type, mode)

    elif args.action == 'list-rollbacks':
        list_rollbacks()

    elif args.action == 'rollback':
        run_rollback(args.file)

if __name__ == "__main__":
    if platform.system() == "Linux" and os.geteuid() != 0:
        print(f"{bcolors.FAIL}Error: This script must be run with sudo on Linux.{bcolors.ENDC}")
        sys.exit(1)
    main()

