-- Starbound Legacy
-- Main game entry point

-- Import game modules
local Player = require("src.entities.player")
local World = require("src.world.world")
local UI = require("src.ui.ui")
local Enemy = require("src.entities.enemy")
local Save = require("src.save.save")

-- Game states
local gameState = {
    MENU = "menu",
    PLAYING = "playing",
    PAUSED = "paused",
    TUTORIAL = "tutorial",
    GAME_OVER = "game_over"
}

-- Current game state
local currentState = gameState.MENU

-- State to return to when unpausing (PLAYING or TUTORIAL)
local stateBeforePause = gameState.PLAYING

-- Message shown on the title screen (for example when loading fails)
local titleMessage = nil

-- Game objects
local player
local world
local ui

-- Camera center in world coordinates; it follows the player
local camera = {x = 0, y = 0}

-- Convert between screen pixels and world coordinates
function screenToWorld(sx, sy)
    return sx + camera.x - love.graphics.getWidth() / 2, sy + camera.y - love.graphics.getHeight() / 2
end

function worldToScreen(wx, wy)
    return wx - camera.x + love.graphics.getWidth() / 2, wy - camera.y + love.graphics.getHeight() / 2
end

-- Initialize game (window size, title and resizing come from conf.lua)
function love.load()
    
    -- Initialize game systems
    initializeGame()
end

-- Initialize game systems
function initializeGame(worldOptions)
    -- Create player at center of screen
    player = Player.new(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)

    -- Create world
    world = World.new(worldOptions)
    world:addEntity(player)
    
    -- Create UI
    ui = UI.new(player, world)

    -- Start the camera on the player
    camera.x, camera.y = player.x, player.y
end

-- Everything needed to restore the current game
function gatherSaveState()
    local function keys(set)
        local list = {}
        for key, value in pairs(set) do
            if value then table.insert(list, key) end
        end
        table.sort(list)
        return list
    end
    local cleared = {}
    for key, chunk in pairs(world.chunks) do
        if chunk.cleared then cleared[key] = true end
    end
    for key in pairs(world.clearedKeys) do cleared[key] = true end

    local weaponDamage = {}
    for name, weapon in pairs(player.weapons) do
        weaponDamage[name] = weapon.damage
    end
    local inventory = {}
    for i, stack in ipairs(player.inventory) do
        inventory[i] = {type = stack.type, count = stack.count}
    end

    return {
        version = Save.VERSION,
        seed = world.seed,
        tutorialCompleted = world.tutorial.completed or not world.tutorial.enabled,
        player = {
            x = player.x, y = player.y,
            health = player.health, shield = player.shield, energy = player.energy,
            currentWeapon = player.currentWeapon,
            weaponDamage = weaponDamage,
            weaponLevels = player.weaponLevels,
            inventory = inventory
        },
        world = {
            startChunkKey = world.startChunkKey,
            startChunk = world.startChunk,
            explored = keys(world.explored),
            cleared = keys(cleared)
        }
    }
end

-- Rebuild the game from saved data
function applySaveState(data)
    initializeGame({seed = data.seed, tutorial = not data.tutorialCompleted})

    local saved = data.player
    player.x, player.y = saved.x, saved.y
    player.health, player.shield, player.energy = saved.health, saved.shield, saved.energy
    player:switchWeapon(saved.currentWeapon)
    for name, damage in pairs(saved.weaponDamage or {}) do
        if player.weapons[name] then player.weapons[name].damage = damage end
    end
    for name, level in pairs(saved.weaponLevels or {}) do
        if player.weaponLevels[name] then player.weaponLevels[name] = level end
    end
    player.inventory = {}
    for i, stack in ipairs(saved.inventory or {}) do
        player.inventory[i] = {type = stack.type, count = stack.count}
    end

    world.startChunkKey = data.world.startChunkKey
    world.startChunk = data.world.startChunk
    for _, key in ipairs(data.world.explored or {}) do world.explored[key] = true end
    for _, key in ipairs(data.world.cleared or {}) do world.clearedKeys[key] = true end

    camera.x, camera.y = player.x, player.y
    currentState = data.tutorialCompleted and gameState.PLAYING or gameState.TUTORIAL
end

-- Carry out a pause menu choice
function activateMenuOption(option)
    if option == "Resume" then
        currentState = stateBeforePause
        ui:toggleMenu()
    elseif option == "Save Game" then
        local ok, err = Save.write(gatherSaveState())
        ui:showMenuMessage(ok and "Game saved" or ("Save failed: " .. tostring(err)))
    elseif option == "Load Game" then
        loadSavedGame()
    elseif option == "Quit" then
        love.event.quit()
    end
end

-- Load the save file; on failure, show why (in the pause menu if it is open)
function loadSavedGame()
    local data, err = Save.read()
    if data then
        applySaveState(data)
        return true
    end
    if ui and ui.showMenu then
        ui:showMenuMessage("Load failed: " .. tostring(err))
    end
    titleMessage = "Load failed: " .. tostring(err)
    return false
end

-- Update game state
function love.update(dt)
    if currentState == gameState.PLAYING or currentState == gameState.TUTORIAL then
        updateGame(dt)
    elseif currentState == gameState.MENU then
        updateMenu(dt)
    elseif currentState == gameState.PAUSED then
        updatePaused(dt)
    end
end

-- Draw game
function love.draw()
    if currentState == gameState.PLAYING or currentState == gameState.TUTORIAL then
        drawGame()
    elseif currentState == gameState.MENU then
        drawMenu()
    elseif currentState == gameState.PAUSED then
        drawPaused()
    elseif currentState == gameState.GAME_OVER then
        drawGameOver()
    end
end

-- Handle keyboard input
function love.keypressed(key, scancode, isrepeat)
    if key == "f3" then
        -- Toggle enemy AI debug rings
        Enemy.debug = not Enemy.debug
    elseif currentState == gameState.PAUSED and (key == "up" or key == "w") then
        ui:menuMove(-1)
    elseif currentState == gameState.PAUSED and (key == "down" or key == "s") then
        ui:menuMove(1)
    elseif currentState == gameState.PAUSED and (key == "return" or key == "kpenter" or key == "space") then
        activateMenuOption(ui:menuSelected())
    elseif key == "l" and currentState == gameState.MENU then
        loadSavedGame()
    elseif key == "escape" then
        if currentState == gameState.PLAYING or currentState == gameState.TUTORIAL then
            stateBeforePause = currentState
            currentState = gameState.PAUSED
            ui:toggleMenu()
        elseif currentState == gameState.PAUSED then
            currentState = stateBeforePause
            ui:toggleMenu()
        end
    elseif key == "i" and (currentState == gameState.PLAYING or currentState == gameState.TUTORIAL) then
        ui:toggleInventory()
    elseif key == "m" and (currentState == gameState.PLAYING or currentState == gameState.TUTORIAL) then
        ui:toggleMap()
    elseif key == "space" and currentState == gameState.MENU then
        currentState = gameState.TUTORIAL
    elseif key == "r" and currentState == gameState.GAME_OVER then
        initializeGame()
        currentState = gameState.MENU
    elseif key == "1" and (currentState == gameState.PLAYING or currentState == gameState.TUTORIAL) then
        player:switchWeapon("laser_pistol")
    elseif key == "2" and (currentState == gameState.PLAYING or currentState == gameState.TUTORIAL) then
        player:switchWeapon("plasma_rifle")
    elseif key == "3" and (currentState == gameState.PLAYING or currentState == gameState.TUTORIAL) then
        player:switchWeapon("ion_cannon")
    elseif key == "4" and (currentState == gameState.PLAYING or currentState == gameState.TUTORIAL) then
        player:switchWeapon("scatter_shot")
    elseif key == "5" and (currentState == gameState.PLAYING or currentState == gameState.TUTORIAL) then
        player:switchWeapon("void_beam")
    elseif (key == "6" or key == "7" or key == "8") and (currentState == gameState.PLAYING or currentState == gameState.TUTORIAL) then
        -- Quick-use inventory slots 1 to 3
        player:useItem(tonumber(key) - 5)
    end
end

-- Handle mouse input
function love.mousepressed(x, y, button)
    if currentState == gameState.PAUSED then
        local option = ui:menuOptionAt(x, y)
        if option and button == 1 then
            ui.menuIndex = option
            activateMenuOption(ui:menuSelected())
        end
        return
    end

    local inGame = currentState == gameState.PLAYING or currentState == gameState.TUTORIAL
    if inGame and ui.showInventory then
        -- Inventory open: click uses an item, right-click drops it; no firing
        local slot = ui:inventorySlotAt(x, y)
        if slot and button == 1 then
            player:useItem(slot)
        elseif slot and button == 2 then
            world:dropItem(player, slot)
        end
        return
    end

    if inGame and button == 1 then
        -- Left click to fire at the world position under the cursor
        player:fire(screenToWorld(x, y))
    end
    
    if ui then
        ui:mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if ui then
        ui:mousereleased(x, y, button)
    end
end

-- Update game logic
function updateGame(dt)
    -- Update player movement
    local dx, dy = 0, 0
    if love.keyboard.isDown("left", "a") then dx = dx - 1 end
    if love.keyboard.isDown("right", "d") then dx = dx + 1 end
    if love.keyboard.isDown("up", "w") then dy = dy - 1 end
    if love.keyboard.isDown("down", "s") then dy = dy + 1 end

    -- Always set velocity so the player stops when no key is held
    player:move(dx, dy)

    -- Aim follows the cursor in world coordinates (charge weapons fire here)
    player.aimX, player.aimY = screenToWorld(love.mouse.getPosition())

    -- Update world
    world:update(dt)

    -- Camera eases toward the player
    local follow = math.min(1, dt * 8)
    camera.x = camera.x + (player.x - camera.x) * follow
    camera.y = camera.y + (player.y - camera.y) * follow

    -- Update UI
    ui:update(dt)
    
    -- Check if tutorial is completed
    if currentState == gameState.TUTORIAL and world.tutorial.completed then
        currentState = gameState.PLAYING
    end

    -- Check for player death
    if player.health <= 0 then
        currentState = gameState.GAME_OVER
    end
end

-- Draw game world
function drawGame()
    -- Draw world through the camera
    love.graphics.push()
    local ox, oy = worldToScreen(0, 0)
    love.graphics.translate(math.floor(ox + 0.5), math.floor(oy + 0.5))
    local viewX0, viewY0 = screenToWorld(0, 0)
    local viewX1, viewY1 = screenToWorld(love.graphics.getWidth(), love.graphics.getHeight())
    world:draw(viewX0, viewY0, viewX1, viewY1)
    love.graphics.pop()

    -- Screen-space world overlays (tutorial text)
    world:drawOverlay()

    -- Draw UI
    ui:draw()
    
    -- Draw current weapon info
    if currentState == gameState.TUTORIAL then
        local weapon = player.weapons[player.currentWeapon]
        love.graphics.setColor(1, 1, 1)
        local h = love.graphics.getHeight()
        love.graphics.print("Current Weapon: " .. weapon.name, 20, h - 40, 0, 1)
        love.graphics.print("Energy: " .. math.floor(player.energy), 20, h - 20, 0, 1)
    end
end

-- Update menu state
function updateMenu(dt)
    -- TODO: Update menu animations, selections
end

-- Draw menu
function drawMenu()
    -- Draw title screen
    love.graphics.setColor(1, 1, 1)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.print("Starbound Legacy", w / 2 - 100, h / 2 - 50, 0, 2)
    love.graphics.print("Press SPACE to Start Tutorial", w / 2 - 100, h / 2 + 50, 0, 1)
    if Save.exists() then
        love.graphics.print("Press L to Load Saved Game", w / 2 - 100, h / 2 + 75, 0, 1)
    end
    if titleMessage then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.print(titleMessage, w / 2 - 100, h / 2 + 100, 0, 1)
    end
end

-- Update paused state
function updatePaused(dt)
    -- Hovering the mouse over an option selects it
    local option = ui:menuOptionAt(love.mouse.getPosition())
    if option then
        ui.menuIndex = option
    end
    ui:update(dt)
end

-- Draw paused state
function drawPaused()
    -- Draw the frozen game behind the pause menu (ui:draw renders the menu overlay)
    drawGame()
end

-- Draw game over screen
function drawGameOver()
    drawGame()

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.printf("GAME OVER", 0, h / 2 - 40, w / 2, "center", 0, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press R to return to the menu", 0, h / 2 + 20, w, "center")
end 