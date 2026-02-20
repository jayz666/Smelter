let currentState = 'idle';
let updateInterval = null;
let availableRecipes = {};
let fuelConfig = {};
let maxBatch = 20;

// Drag functionality
let isDragging = false;
let dragOffset = { x: 0, y: 0 };

// Initialize drag functionality
document.addEventListener('DOMContentLoaded', function() {
    const container = document.getElementById('smelterUI');
    const header = document.querySelector('.header');
    
    if (container && header) {
        header.style.cursor = 'move';
        header.addEventListener('mousedown', startDrag);
    }
    
    document.addEventListener('mousemove', drag);
    document.addEventListener('mouseup', stopDrag);
});

function startDrag(e) {
    const container = document.getElementById('smelterUI');
    if (!container) return;
    
    isDragging = true;
    dragOffset.x = e.clientX - container.offsetLeft;
    dragOffset.y = e.clientY - container.offsetTop;
    
    // Disable transition during drag
    container.style.transition = 'none';
}

function drag(e) {
    if (!isDragging) return;
    
    const container = document.getElementById('smelterUI');
    if (!container) return;
    
    const newX = e.clientX - dragOffset.x;
    const newY = e.clientY - dragOffset.y;
    
    // Keep within viewport bounds
    const maxX = window.innerWidth - container.offsetWidth;
    const maxY = window.innerHeight - container.offsetHeight;
    
    container.style.left = Math.max(0, Math.min(newX, maxX)) + 'px';
    container.style.top = Math.max(0, Math.min(newY, maxY)) + 'px';
    container.style.transform = 'none'; // Remove center transform when dragging
}

function stopDrag() {
    if (!isDragging) return;
    
    isDragging = false;
    const container = document.getElementById('smelterUI');
    if (container) {
        container.style.transition = ''; // Restore transition
    }
}

// Message listener
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'open':
            availableRecipes = data.data.recipes;
            fuelConfig = data.data.fuel;
            maxBatch = data.data.maxBatch;

            const uiElement = document.getElementById('smelterUI');
            uiElement.style.display = 'block';
            document.body.style.display = 'block';

            // Reset to default position
            uiElement.style.left = '40px';
            uiElement.style.top = '50%';
            uiElement.style.transform = 'translateY(-50%)';
            uiElement.style.transition = 'transform 0.2s ease';

            populateRecipeDropdown();
            showIdleState();
            break;
            
        case 'skills':
            updateSkills(data.data);
            break;
            
        case 'state':
            if (data.data.mode === 'idle') {
                showIdleState();
            } else if (data.data.mode === 'active') {
                showActiveState(data.data.recipe, data.data.amount, data.data.remaining);
            } else if (data.data.mode === 'ready') {
                showReadyState(data.data.recipe, data.data.amount);
            }
            break;
            
        case 'hideUI':
            document.getElementById('smelterUI').style.display = 'none';
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
            
        case 'showUI':
            document.body.style.display = 'block';
            break;
            
        case 'hideUI':
            document.body.style.display = 'none';
            clearInterval(updateInterval);
            updateInterval = null;
            handleStateUpdate(data.data);
            break;
    }
});

function getProgress(xp, prev, next) {
  if (typeof xp !== 'number') xp = 0;
  if (typeof prev !== 'number') prev = 0;
  if (typeof next !== 'number') next = prev;

  if (next <= prev) return 100; // max level
  const pct = ((xp - prev) / (next - prev)) * 100;
  return Math.max(0, Math.min(100, pct));
}

function updateSkills(skills) {
  if (!skills) return;

  const levelEl = document.getElementById('skillLevel');
  const xpEl = document.getElementById('skillXpText');
  const barEl = document.getElementById('xpProgress');

  if (!levelEl || !xpEl || !barEl) return;

  const xp = skills.xp ?? 0;
  const level = skills.level ?? 1;
  const prev = skills.prevLevelXp ?? 0;
  const next = skills.nextLevelXp ?? prev;

  levelEl.textContent = `Level ${level}`;

  if (next <= prev) {
    xpEl.textContent = `${xp} XP (MAX)`;
    barEl.style.width = `100%`;
  } else {
    xpEl.textContent = `${xp} XP / ${next} XP`;
    const progress = getProgress(xp, prev, next);
    barEl.style.width = `${progress}%`;
  }

  // Optional one-line stats (if you add the element)
  const statsEl = document.getElementById('skillStats');
  if (statsEl) {
    statsEl.textContent =
      `Smelted: ${skills.total_items_smelted ?? 0} | Fuel: ${skills.total_fuel_used ?? 0} | Jobs: ${skills.total_jobs_completed ?? 0}`;
  }
}

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
        
        // Clear any existing timer
        if (updateInterval) {
            clearInterval(updateInterval);
        }
        
        // Start live countdown
        updateInterval = setInterval(() => {
            if (remaining > 0) {
                remaining--;
                const timeText = formatTime(remaining);
                statusBox.innerHTML = `
                    <div>${processingText}</div>
                    <div style="font-size: 12px; opacity: 0.8; margin-top: 4px;">Time remaining: ${timeText}</div>
                `;
            } else {
                clearInterval(updateInterval);
                updateInterval = null;
                // Auto-refresh to check if job is ready
                fetch(`https://${GetParentResourceName()}/requestStatus`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({})
                });
            }
        }, 1000);
        
        // Initial display
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
