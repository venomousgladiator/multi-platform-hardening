
Multi-Platform OS Hardening Tool
A web-based, cross-platform tool designed to audit and apply security hardening baselines on Windows and Linux systems. This tool provides a simple, centralized dashboard to enforce security policies based on industry standards, with a built-in safety net for rolling back changes.

✨ Features
Cross-Platform: A single application that runs on and hardens both Windows (10+) and Linux (Ubuntu 20.04+) systems.

Web-Based UI: Modern, accessible dashboard that can be accessed from a browser on the local machine.

Real-time Feedback: Uses WebSockets to provide instant results from script execution without needing to reload the page.

Policy-Based Hardening: Implements security controls based on the provided Annexure A (Windows) and Annexure B (Linux).

Safety First Rollback: Automatically saves the state of a setting before applying a change and provides an easy one-click option to revert.

🛠️ Tech Stack
Backend: Python with Flask and Flask-SocketIO.

Frontend: HTML, CSS, and vanilla JavaScript.

Scripting Engine:

PowerShell (.ps1) for deep integration with Windows.

Bash (.sh) for universal compatibility on Linux.

📂 Project Structure
The project is organized into a clean and scalable structure:

/
├── app.py                  # Main Flask web server
├── scripts/
│   ├── windows/            # PowerShell scripts for Windows
│   └── linux/              # Bash scripts for Linux
├── templates/
│   └── index.html          # Frontend HTML template
├── static/
│   ├── css/style.css       # Styles for the web interface
│   └── js/main.js          # Client-side JavaScript for interactivity
├── rollback/               # Stores JSON files for rollback states
└── requirements.txt        # Python dependencies
🚀 Setup and Installation
Follow these steps on the target machine (either a Windows or Ubuntu VM) where you want to run the tool.

Prerequisites: General
Git: Required to clone the repository.

Prerequisites: Windows 10/11
Install Python: Download and install Python from python.org. Important: Check the box that says "Add Python to PATH" during installation.

Set PowerShell Execution Policy: Open PowerShell as an Administrator and run:

PowerShell

Set-ExecutionPolicy RemoteSigned -Force
Prerequisites: Ubuntu 20.04+
Install Python, Pip, and jq:

Bash

sudo apt update && sudo apt upgrade -y
sudo apt install python3 python3-pip jq -y
Installation Steps
Clone the Repository:

Bash

git clone https://github.com/venomousgladiator/multi-platform-hardening.git
cd multi-platform-hardening
Install Python Dependencies:

Bash

pip install -r requirements.txt
(Linux Only) Make Scripts Executable:

Bash

chmod +x scripts/linux/*.sh
⚡ How to Run
The application must be run with elevated privileges to apply hardening policies.

On Windows: Open a Command Prompt or PowerShell as an Administrator, navigate to the project directory, and run:

PowerShell

python app.py
On Linux: Open a terminal, navigate to the project directory, and run:

Bash

sudo python3 app.py
Once the server is running, open a web browser and navigate to http://127.0.0.1:5000.

📖 How to Use
Check a Policy: Click the "Check" button next to any policy to see the current configuration on the system.

Apply a Policy: Click the "Apply" button to enforce the recommended hardening setting. The previous state will be saved automatically.

View Rollbacks: After applying a policy, click the "Refresh Rollbacks" button at the bottom of the page.

Perform a Rollback: A list of saved states will appear. Click the "Rollback" button next to a file to revert the change to its original state.