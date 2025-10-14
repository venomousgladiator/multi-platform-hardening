// Connect to the WebSocket server in our Python app
const socket = io();

/**
 * Sends a command to the backend to execute a script.
 * @param {string} scriptName - The name of the script to run.
 */
function runScript(scriptName) {
    const resultsDiv = document.getElementById('results');
    resultsDiv.textContent = `Executing ${scriptName}...`;
    // Emit the 'run_script' event with the script name
    socket.emit('run_script', { script_name: scriptName });
}

// Listen for the 'script_result' event from the server
socket.on('script_result', function(data) {
    const resultsDiv = document.getElementById('results');
    try {
        // The backend sends the output as a string, which should be JSON.
        // We need to parse it to access the data.
        const parsedData = JSON.parse(data.output);
        
        // Format the parsed JSON for clean display
        let formattedOutput = `Parameter: ${parsedData.parameter}\n`;
        formattedOutput += `Status:    ${parsedData.status}\n`;
        formattedOutput += `Details:   ${parsedData.details}`;
        
        resultsDiv.textContent = formattedOutput;
    } catch (e) {
        // If the output isn't valid JSON, display the raw output
        resultsDiv.textContent = data.output;
    }
});


function listRollbacks() {
    const container = document.getElementById('rollback-container');
    container.innerHTML = '<p>Loading...</p>';
    socket.emit('list_rollbacks');
}

/**
 * Executes a specific rollback file.
 * @param {string} filename - The name of the rollback file to execute.
 */
function runRollback(filename) {
    const resultsDiv = document.getElementById('results');
    resultsDiv.textContent = `Executing rollback for ${filename}...`;
    socket.emit('run_rollback', { filename: filename });
}

// Listen for the 'rollback_list' event from the server
socket.on('rollback_list', function(data) {
    const container = document.getElementById('rollback-container');
    container.innerHTML = ''; // Clear the container

    if (data.error) {
        container.innerHTML = `<p>Error loading rollbacks: ${data.error}</p>`;
        return;
    }

    if (data.files && data.files.length > 0) {
        data.files.forEach(filename => {
            const rollbackItem = document.createElement('div');
            rollbackItem.className = 'policy'; // Reuse the policy style
            
            const label = document.createElement('span');
            label.textContent = filename;
            
            const button = document.createElement('button');
            button.textContent = 'Rollback';
            button.onclick = () => runRollback(filename);
            
            rollbackItem.appendChild(label);
            rollbackItem.appendChild(button);
            container.appendChild(rollbackItem);
        });
    } else {
        container.innerHTML = '<p>No rollback files found.</p>';
    }
});