import subprocess
import sys
import json
import argparse

def run_script(script_name):
    """A simple function to run a script and print its JSON output."""
    if sys.platform == "win32":
        command = f"powershell.exe -ExecutionPolicy Bypass -File .\\scripts\\windows\\{script_name}"
    else:
        command = f"./scripts/linux/{script_name}"
    
    try:
        output = subprocess.check_output(command, shell=True, text=True, stderr=subprocess.PIPE)
        print(json.dumps(json.loads(output), indent=4))
    except subprocess.CalledProcessError as e:
        print(json.dumps({"error": e.stderr.strip()}, indent=4))

def main():
    parser = argparse.ArgumentParser(description="Multi-Platform OS Hardening CLI")
    parser.add_argument("script", help="The name of the script to execute (e.g., Get-PasswordHistory.ps1)")
    
    args = parser.parse_args()
    
    print(f"--- Executing: {args.script} ---")
    run_script(args.script)
    print("-------------------------")

if __name__ == "__main__":
    main()