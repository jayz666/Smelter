let currentState = 'idle';
let updateInterval = null;
let availableRecipes = {};
let fuelConfig = {};
let maxBatch = 20;

// Message listener
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'showUI':
            document.body.style.display = 'block';
            break;
            
        case 'hideUI':
            document.body.style.display = 'none';
            clearInterval(updateInterval);
            updateInterval = null;
            break;
            
        case 'initRecipes':
            availableRecipes = data.data || {};
            populateRecipeDropdown();
            break;
            
        case 'initFuel':
            fuelConfig = data.data || {};
            updateFuelRequirement();
            break;
            
        case 'initMeta':
            availableRecipes = data.data.recipes || {};
            fuelConfig = data.data.fuel || {};
            maxBatch = data.data.maxBatch || 20;
            populateRecipeDropdown();
            break;
            
        case 'state':
            handleStateUpdate(data.data);
            break;
    }
});

// Recipe management
function populateRecipeDropdown() {
    const select = document.getElementById('recipeSelect');
    select.innerHTML = '';
    
    for (const [key, recipe] of Object.entries(availableRecipes)) {
        const option = document.createElement('option');
        option.value = key;
        option.textContent = recipe.label;
        select.appendChild(option);
    }
    
    updateRecipeInfo();
    updateFuelRequirement();
}

function updateRecipeInfo() {
    const select = document.getElementById('recipeSelect');
    const recipeKey = select.value;
    const recipe = availableRecipes[recipeKey];
    
    if (recipe) {
        document.getElementById('inputItemName').textContent = recipe.input.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase());
        document.getElementById('outputItemName').textContent = recipe.output.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase());
    } else {
        document.getElementById('inputItemName').textContent = '-';
        document.getElementById('outputItemName').textContent = '-';
    }
}

function updateFuelRequirement() {
    const select = document.getElementById('recipeSelect');
    const amountInput = document.getElementById('amountInput');
    const recipeKey = select.value;
    const recipe = availableRecipes[recipeKey];
    const amount = parseInt(amountInput.value) || 1;
    
    if (recipe && fuelConfig.burnTime) {
        const totalTime = amount * recipe.baseTime;
        const requiredFuel = Math.ceil(totalTime / fuelConfig.burnTime);
        document.getElementById('fuelRequirement').textContent = `Requires: ${requiredFuel} coal`;
    } else {
        document.getElementById('fuelRequirement').textContent = 'Requires: 0 coal';
    }
}

// State management
function handleStateUpdate(data) {
    if (!data || !data.mode) return;
    
    currentState = data.mode;
    clearInterval(updateInterval);
    updateInterval = null;
    
    // Reset UI elements
    document.getElementById('recipeSection').style.display = 'block';
    document.getElementById('amountSection').style.display = 'block';
    document.getElementById('buttonSection').style.display = 'block';
    document.getElementById('statusSection').style.display = 'block';
    document.getElementById('startBtn').style.display = 'block';
    document.getElementById('collectBtn').style.display = 'none';
    
    const statusBox = document.getElementById('statusBox');
    statusBox.className = 'status';
    statusBox.innerHTML = '';
    
    switch (data.mode) {
        case 'idle':
            showIdleState();
            break;
            
        case 'active':
            showActiveState(data.recipe, data.amount, data.remaining);
            break;
            
        case 'ready':
            showReadyState(data.recipe, data.amount);
            break;
            
        case 'error':
            showErrorState(data.message);
            break;
    }
}

function showIdleState() {
    document.getElementById('recipeSection').style.display = 'block';
    document.getElementById('amountSection').style.display = 'block';
    document.getElementById('startBtn').style.display = 'block';
    document.getElementById('statusBox').innerHTML = 'Select recipe and amount to begin';
}

function showActiveState(recipeKey, amount, remaining) {
    const recipe = availableRecipes[recipeKey];
    const statusBox = document.getElementById('statusBox');
    
    statusBox.className = 'status processing';
    
    if (recipe) {
        const processingText = `Smelting ${amount} ${recipe.input.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())} → ${amount} ${recipe.output.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}`;
        const timeText = typeof remaining === 'number' ? formatTime(remaining) : 'Calculating...';
        
        statusBox.innerHTML = `
            <div>${processingText}</div>
            <div style="font-size: 12px; opacity: 0.8; margin-top: 4px;">Time remaining: ${timeText}</div>
        `;
    }
    
    document.getElementById('recipeSection').style.display = 'none';
    document.getElementById('amountSection').style.display = 'none';
    document.getElementById('startBtn').style.display = 'none';
    document.getElementById('collectBtn').style.display = 'block';
}

function showReadyState(recipeKey, amount) {
    const recipe = availableRecipes[recipeKey];
    const statusBox = document.getElementById('statusBox');
    
    statusBox.className = 'status ready';
    
    if (recipe) {
        const readyText = `Ready to collect ${amount} ${recipe.output.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}!`;
        statusBox.innerHTML = readyText;
    }
    
    document.getElementById('recipeSection').style.display = 'none';
    document.getElementById('amountSection').style.display = 'none';
    document.getElementById('startBtn').style.display = 'none';
    document.getElementById('collectBtn').style.display = 'block';
}

function showErrorState(message) {
    const statusBox = document.getElementById('statusBox');
    statusBox.className = 'status error';
    statusBox.innerHTML = message || 'An error occurred';
    
    // Return to idle after 3 seconds
    setTimeout(() => {
        if (currentState === 'error') {
            handleStateUpdate({ mode: 'idle' });
        }
    }, 3000);
}

function formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
}

// Button handlers
document.getElementById('startBtn').addEventListener('click', function() {
    const recipe = document.getElementById('recipeSelect').value;
    const amount = parseInt(document.getElementById('amountInput').value);
    
    if (recipe && amount >= 1 && amount <= maxBatch) {
        fetch(`https://${GetParentResourceName()}/startJob`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({ recipe: recipe, amount: amount })
        });
    } else {
        showErrorState(`Invalid input (1-${maxBatch})`);
    }
});

document.getElementById('collectBtn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/collectJob`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    });
});

// Input change handlers
document.getElementById('recipeSelect').addEventListener('change', function() {
    updateRecipeInfo();
    updateFuelRequirement();
});

document.getElementById('amountInput').addEventListener('input', updateFuelRequirement);

// Escape key handler
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        fetch(`https://${GetParentResourceName()}/closeUI`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({})
        });
    }
});

// Initial state
document.body.style.display = 'none';
