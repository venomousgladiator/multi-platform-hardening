import subprocess
import sys
import json
import argparse
import platform
import os
import logging
from logging.handlers import RotatingFileHandler

# --- 1. Setup Logging ---
if not os.path.exists('logs'):
    os.makedirs('logs')

log_handler = RotatingFileHandler('logs/syswarden_cli.log', maxBytes=100000, backupCount=5)
log_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s: %(message)s'))
logger = logging.getLogger(__name__)
logger.addHandler(log_handler)
logger.setLevel(logging.INFO)

# --- 2. Define Hardening Modules ---
# This is the master list of modules the CLI knows how to call.
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

def run_hardening_profile(modules, level, os_type):
    """Executes a list of modules, passing the level to each."""
    print(f"\n{bcolors.BOLD}Starting hardening process for Level {level}...{bcolors.ENDC}")
    
    for i, module_name in enumerate(modules):
        print(f"\n[{i+1}/{len(modules)}] {bcolors.HEADER}--- Executing Module: {module_name} ---{bcolors.ENDC}")
        logger.info(f"Executing module: {module_name} for Level {level}")
        
        if os_type == "Windows":
            command = f"powershell.exe -ExecutionPolicy Bypass -File .\\scripts\\windows\\modules\\{module_name} -Level {level}"
        else:
            command = f"./scripts/linux/modules/{module_name} {level}"
        
        try:
            process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            
            # Stream stdout for real-time results
            for line in process.stdout:
                try:
                    data = json.loads(line)
                    status_color = bcolors.OKGREEN if data.get('status') == 'Success' else bcolors.FAIL
                    details = data.get('details', 'No details provided.')
                    parameter = data.get('parameter', 'Unknown Parameter')
                    print(f"  [{status_color}{data.get('status', 'ERROR')}{bcolors.ENDC}] {parameter}: {details}")
                    logger.info(f"[{data.get('status', 'ERROR')}] {parameter}: {details}")
                except (json.JSONDecodeError, KeyError):
                    print(f"  {bcolors.WARNING}RAW: {line.strip()}{bcolors.ENDC}")

            # Wait for the process to finish and capture any errors
            stderr = process.communicate()[1]
            if process.returncode != 0:
                print(f"  {bcolors.FAIL}MODULE ERROR:{bcolors.ENDC} Module '{module_name}' exited with a non-zero status.")
                print(f"  {bcolors.FAIL}STDERR: {stderr.strip()}{bcolors.ENDC}")
                logger.error(f"Module '{module_name}' exited with error: {stderr.strip()}")

        except Exception as e:
            print(f"  {bcolors.FAIL}FATAL ERROR:{bcolors.ENDC} Could not execute module {module_name}. Error: {e}")
            logger.critical(f"FATAL ERROR executing {module_name}: {e}")

def main():
    parser = argparse.ArgumentParser(
        description="SysWarden: A CLI for applying security hardening profiles.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "action", 
        choices=['harden'], 
        help="The action to perform."
    )
    parser.add_argument(
        "--level",
        choices=['L1', 'L2', 'L3'],
        required=True,
        help="The hardening level to apply.\n"
             "L1: Essential - Basic security hygiene.\n"
             "L2: Recommended - More comprehensive security (includes L1).\n"
             "L3: Strict - Highest security (includes L1 & L2)."
    )

    args = parser.parse_args()
    os_type = platform.system()

    print(f"{bcolors.HEADER}--- SysWarden CLI ---{bcolors.ENDC}")
    print(f"Detected Operating System: {bcolors.BOLD}{os_type}{bcolors.ENDC}")
    
    logger.info(f"SysWarden CLI initiated for {os_type} with action '{args.action}' at level '{args.level}'.")

    if args.action == 'harden':
        modules_to_run = []
        if os_type == "Windows":
            if args.level == "L1": modules_to_run.extend(WINDOWS_MODULES["L1"])
            if args.level == "L2": modules_to_run.extend(WINDOWS_MODULES["L1"] + WINDOWS_MODULES["L2"])
            if args.level == "L3": modules_to_run.extend(WINDOWS_MODULES["L1"] + WINDOWS_MODULES["L2"] + WINDOWS_MODULES["L3"])
        elif os_type == "Linux":
            if args.level == "L1": modules_to_run.extend(LINUX_MODULES["L1"])
            if args.level == "L2": modules_to_run.extend(LINUX_MODULES["L1"] + LINUX_MODULES["L2"])
            if args.level == "L3": modules_to_run.extend(LINUX_MODULES["L1"] + LINUX_MODULES["L2"] + LINUX_MODULES["L3"])
        else:
            print(f"{bcolors.FAIL}Error: Unsupported operating system.{bcolors.ENDC}")
            sys.exit(1)
        
        run_hardening_profile(modules_to_run, args.level, os_type)

if __name__ == "__main__":
    if platform.system() == "Linux" and os.geteuid() != 0:
        print(f"{bcolors.FAIL}Error: This script must be run with sudo on Linux.{bcolors.ENDC}")
        sys.exit(1)
    main()