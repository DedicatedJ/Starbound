-- The Last Starchart
-- Main game entry point

-- Import game modules
local Player = require("src.entities.player")
local World = require("src.world.world")
local UI = require("src.ui.ui")
local Enemy = require("src.entities.enemy")
local Save = require("src.save.save")
local Session = require("src.game.session")
local StarMap = require("src.ui.starmap")
local Shop = require("src.ui.shop")
local Upgrades = require("src.game.upgrades")
local Vault = require("src.world.vault")
local Story = require("src.data.story")
local Dialogue = require("src.ui.dialogue")

-- Game states
local gameState = {
    MENU = "menu",
    PLAYING = "playing",
    PAUSED = "paused",
    TUTORIAL = "tutorial",
    STARMAP = "starmap",
    SHOP = "shop",
    DIALOGUE = "dialogue",
    ENDING = "ending",
GAME_OVER = "game_over"
}

-- Current game state
local currentState = gameState.MENU

-- State to return to when unpausing (PLAYING or TUTORIAL)
local stateBeforePause = gameState.PLAYING

-- Message shown on the title screen (for example when loading fails)
local titleMessage = nil

-- Game objects
local session     -- campaign state: location, fuel, upgrades, story
local worlds      -- location id -> World, kept while the game runs
local player
local world       -- the world the player is in now
local ui
local starMap
local shop
local dialogue = Dialogue.new()
local dialogueReturnState   -- where the open dialogue returns to
local endingId          -- which ending is being shown

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
    initializeGame()
end

-- Start a new campaign; options.seed picks the galaxy, options.tutorial=false skips the tutorial
function initializeGame(options)
    options = options or {}
    session = Session.new(options.seed)
    worlds = {}
    world = nil

    local lx, ly = World.landingSite()
    player = Player.new(lx, ly)
    ui = UI.new(player, nil)
    ui.session = session
    starMap = StarMap.new(session)
    shop = Shop.new(session, player)

    enterLocation(session.location, {tutorial = options.tutorial ~= false})
end

-- Build the world for a location and place its fixed objects
function createWorld(id, tutorial)
    local loc = Session.locationData(id)
    local newWorld = World.new({
        seed = session:locationSeed(id),
        biomes = loc.biomes,
        tutorial = tutorial == true,
        spawnEnemies = not loc.safe,
        levelBonus = loc.levelBonus or 0,
        bounds = loc.kind == "station" and World.chunkBounds(1) or nil
    })

    -- Every location has the ship at the landing site
    local lx, ly = World.landingSite()
    newWorld:addInteractable({
        id = "ship", kind = "ship", label = "Your ship",
        x = lx - 60, y = ly, radius = 70,
        prompt = "[E] Open the star map",
        onInteract = function() openStarMap() end
    })

    -- Fragment planets: a vault a few chunks from the landing site, in a seeded direction
    if loc.fragment then
        local rng = love.math.newRandomGenerator(session:locationSeed(id) + 17)
        local angle = rng:random() * math.pi * 2
        local distance = World.chunkPixels() * 4
        Vault.new(newWorld, {
            x = lx + math.cos(angle) * distance,
            y = ly + math.sin(angle) * distance,
            puzzle = loc.puzzle,
            seed = session:locationSeed(id) + 99,
            enemyType = loc.biomes[1] == "jungle" and "ALIEN_WILDLIFE" or "SPACE_PIRATE",
            notify = function(text) notify(text) end,
            onCollect = function() collectFragment(id) end
        })
    end

    -- The Rift: the Arkadia drifts a few chunks from the landing site
    if loc.kind == "rift" then
        local rng = love.math.newRandomGenerator(session:locationSeed(id) + 31)
        local angle = rng:random() * math.pi * 2
        local distance = World.chunkPixels() * 2
        newWorld.arkadia = newWorld:addInteractable({
            id = "arkadia", label = "The Arkadia",
            x = lx + math.cos(angle) * distance, y = ly + math.sin(angle) * distance, radius = 110,
            prompt = "[E] Board the Arkadia",
            onInteract = function() boardArkadia() end,
            draw = function(obj)
                love.graphics.setColor(0.85, 0.9, 1)
                love.graphics.polygon("fill", obj.x, obj.y - 90, obj.x + 70, obj.y + 60, obj.x, obj.y + 30, obj.x - 70, obj.y + 60)
                love.graphics.setColor(0.4, 1, 0.6, 0.5 + 0.5 * math.sin(love.timer.getTime() * 2))
                love.graphics.circle("fill", obj.x, obj.y, 16)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(obj.label, obj.x - 80, obj.y - 120, 160, "center")
            end
        })
    end

    -- Drift Station: Quill and the upgrade terminal
    if loc.kind == "station" then
        newWorld:addInteractable({
            id = "quill", label = "Quill", color = {0.7, 0.85, 1}, size = 14,
            x = lx - 140, y = ly - 90, radius = 60,
            prompt = "[E] Talk to Quill",
            onInteract = function() talkToQuill() end
        })
        newWorld:addInteractable({
            id = "terminal", kind = "terminal", label = "Upgrade terminal",
            x = lx + 140, y = ly - 90, radius = 60,
            prompt = "[E] Browse upgrades",
            onInteract = function() openShop() end
        })
    end
    return newWorld
end

-- Move the player to a location (creating its world on the first visit)
function enterLocation(id, options)
    options = options or {}
    if world then
        world:removeEntity(player)
    end
    world = worlds[id]
    if not world then
        world = createWorld(id, options.tutorial)
        worlds[id] = world
    end
    world:addEntity(player)
    session.location = id

    if not options.keepPosition then
        -- Step off the ship
        local lx, ly = World.landingSite()
        player.x, player.y = lx, ly
    end
    player.projectiles = {}
    player.velocity.x, player.velocity.y = 0, 0

    ui.world = world
    camera.x, camera.y = player.x, player.y

    -- Varro's truce makes pirates passive everywhere
    world.passivePirates = session.flags.pirate_deal == true

    -- Refresh the HUD now; an arrival dialogue may run before the next game update
    ui.prompt = nil
    ui.objective = currentObjective()

    if not options.keepPosition then
        onArrive(id)
    end
end

-- Story events when landing somewhere
function onArrive(id)
    if id == "cinder" and not session.flags.varro_contact then
        session.flags.varro_contact = true
        startDialogue(Story.varroContact, {onDone = function(choice)
            if choice == "deal" then
                session.flags.pirate_deal = true
                world.passivePirates = true
                for _, enemy in ipairs(world.enemies) do
                    if enemy.type == "SPACE_PIRATE" then enemy.passive = true end
                end
                startDialogue(Story.varroDeal)
            else
                session.flags.defied_varro = true
                startDialogue(Story.varroRefuse)
            end
        end})
    elseif id == "the_rift" and not session.flags.rift_arrival then
        session.flags.rift_arrival = true
        local lines = {}
        for _, line in ipairs(Story.riftArrival) do table.insert(lines, line) end
        if session.flags.defied_varro then
            for _, line in ipairs(Story.riftVarro) do table.insert(lines, line) end
        end
        startDialogue(lines)
    end
end

-- Show a dialogue; the game pauses behind it and resumes when it ends
function startDialogue(lines, options)
    options = options or {}
    -- A dialogue started while another is open returns where the first one would have
    local returnState = options.returnState
        or (currentState == gameState.DIALOGUE and dialogueReturnState)
        or currentState
    dialogueReturnState = returnState
    currentState = gameState.DIALOGUE
    if ui then ui.prompt = nil end   -- no interaction prompt showing through the dialogue box
    dialogue:start(lines, {
        skippable = options.skippable,
        flags = session.flags,
        onDone = function(choice)
            currentState = returnState
            if options.onDone then options.onDone(choice) end
        end
    })
end

function talkToQuill()
    if not session.flags.met_quill then
        session.flags.met_quill = true
        startDialogue(Story.quillFirst)
    elseif session:fragmentCount() >= 3 and not session.flags.mara_alive_clue then
        session.flags.mara_alive_clue = true
        startDialogue(Story.quillTruth)
    else
        startDialogue(Story.quillHint(session))
    end
end

function boardArkadia()
    startDialogue(Story.arkadia, {onDone = function(choice)
        if choice then showEnding(choice) end
    end})
end

function showEnding(id)
    endingId = id
    session.flags.ending = id
    currentState = gameState.ENDING
end

-- What the player should do next, shown in the HUD
function currentObjective()
    if world:tutorialActive() then
        return "Finish the tutorial"
    elseif not session.flags.met_quill then
        return session.location == "drift_station" and "Talk to Quill" or "Fly to Drift Station (press E at your ship)"
    end
    local count = session:fragmentCount()
    if count < 3 then
        local text = ("Recover the star map fragments (%d/3)"):format(count)
        if world.vault and not world.vault.collected then
            return text .. ": open this world's vault"
        elseif not session:hasUpgrade("jump_drive") and count >= 1 then
            return text .. ": buy the Jump Drive Mk II at Drift Station"
        end
        return text .. ": Cinder, Glacius, Verdant Deep"
    elseif not session.flags.mara_alive_clue then
        return "Return to Quill at Drift Station"
    elseif not session:hasUpgrade("void_shielding") then
        return "Buy Void Shielding at Drift Station"
    elseif session.location ~= "the_rift" then
        return "Jump to the Rift"
    end
    return "Board the Arkadia"
end

-- Short message at the top of the screen
function notify(text, seconds)
    if ui then ui:notify(text, seconds) end
end

-- Taking a star map fragment from a vault: progress plus a material reward
function collectFragment(locationId)
    session.fragments[locationId] = true
    local reward = {"salvage", "salvage", "salvage", "alien_essence", "alien_essence"}
    for _, itemType in ipairs(reward) do
        if not player:addItem(itemType) then
            -- Inventory full: leave it on the ground
            local Loot = require("src.entities.loot")
            table.insert(world.loot, Loot.new(player.x, player.y, itemType))
        end
    end
    notify(("Star map fragment recovered (%d of 3). The vault also held salvage and alien essence."):format(session:fragmentCount()), 6)
    if Story.logs[locationId] then
        startDialogue(Story.logs[locationId])
    end
end

-- Arrow toward a world position: a marker above it when on screen, otherwise at the screen edge
local function drawMarker(wx, wy, label, offScreenOnly)
    local sx, sy = worldToScreen(wx, wy)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local distance = math.floor(math.sqrt((wx - player.x) ^ 2 + (wy - player.y) ^ 2) / 32)
    love.graphics.setColor(1, 0.9, 0.3)
    if sx >= 0 and sx <= w and sy >= 0 and sy <= h then
        if not offScreenOnly then
            love.graphics.polygon("fill", sx, sy - 90, sx - 8, sy - 104, sx + 8, sy - 104)
        end
        return
    end
    local cx, cy = w / 2, h / 2
    local angle = math.atan2(sy - cy, sx - cx)
    local margin = 40
    local scale = math.min((w / 2 - margin) / math.max(1e-6, math.abs(math.cos(angle))),
        (h / 2 - margin) / math.max(1e-6, math.abs(math.sin(angle))))
    local ex, ey = cx + math.cos(angle) * scale, cy + math.sin(angle) * scale
    love.graphics.push()
    love.graphics.translate(ex, ey)
    love.graphics.rotate(angle)
    love.graphics.polygon("fill", 14, 0, -8, -9, -8, 9)
    love.graphics.pop()
    love.graphics.printf(("%s %dm"):format(label, distance), ex - 60, ey + 14, 120, "center")
end

function openShop()
    shop.message = nil
    currentState = gameState.SHOP
end

function openStarMap()
    starMap:open()
    currentState = gameState.STARMAP
end

-- Jump to the location selected on the star map
function travelToSelected()
    local target = starMap:selectedLocation()
    local ok, reason = session:travel(target.id)
    if not ok then
        starMap.message = reason
        return false
    end
    -- Set the state first: arriving may start a dialogue
    currentState = gameState.PLAYING
    enterLocation(target.id)
    return true
end

-- Use the nearest interactable, if any
function interact()
    local obj = world:nearestInteractable(player.x, player.y)
    if not obj then return false end
    if world:tutorialActive() then
        return false
    end
    obj.onInteract(obj)
    return true
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

    local worldStates = {}
    for id, w in pairs(worlds) do
        local cleared = {}
        for key, chunk in pairs(w.chunks) do
            if chunk.cleared then cleared[key] = true end
        end
        for key in pairs(w.clearedKeys) do cleared[key] = true end
        worldStates[id] = {
            tutorialCompleted = w.tutorial.completed or not w.tutorial.enabled,
            startChunkKey = w.startChunkKey,
            startChunk = w.startChunk,
            explored = keys(w.explored),
            cleared = keys(cleared),
            state = w.saveState and w:saveState() or nil
        }
    end

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
        session = session:serialize(),
        player = {
            x = player.x, y = player.y,
            health = player.health, shield = player.shield, energy = player.energy,
            maxHealth = player.maxHealth, maxShield = player.maxShield, maxEnergy = player.maxEnergy,
            currentWeapon = player.currentWeapon,
            weaponDamage = weaponDamage,
            weaponLevels = player.weaponLevels,
            inventory = inventory
        },
        worlds = worldStates
    }
end

-- Rebuild the game from saved data
function applySaveState(data)
    session = Session.fromSave(data.session)
    worlds = {}
    world = nil

    local saved = data.player
    player = Player.new(saved.x, saved.y)
    player.maxHealth = saved.maxHealth or player.maxHealth
    player.maxShield = saved.maxShield or player.maxShield
    player.maxEnergy = saved.maxEnergy or player.maxEnergy
    player.health, player.shield, player.energy = saved.health, saved.shield, saved.energy
    player:switchWeapon(saved.currentWeapon)
    for name, damage in pairs(saved.weaponDamage or {}) do
        if player.weapons[name] then player.weapons[name].damage = damage end
    end
    for name, level in pairs(saved.weaponLevels or {}) do
        if player.weaponLevels[name] then player.weaponLevels[name] = level end
    end
    for i, stack in ipairs(saved.inventory or {}) do
        player.inventory[i] = {type = stack.type, count = stack.count}
    end

    ui = UI.new(player, nil)
    ui.session = session
    starMap = StarMap.new(session)
    shop = Shop.new(session, player)
    Upgrades.applyToPlayer(session, player)
    player.health, player.shield, player.energy = saved.health, saved.shield, saved.energy

    -- Recreate every visited world with its explored and cleared chunks
    for id, ws in pairs(data.worlds or {}) do
        if Session.locationData(id) then
            local w = createWorld(id, not ws.tutorialCompleted)
            w.startChunkKey = ws.startChunkKey
            w.startChunk = ws.startChunk
            for _, key in ipairs(ws.explored or {}) do w.explored[key] = true end
            for _, key in ipairs(ws.cleared or {}) do w.clearedKeys[key] = true end
            if ws.state and w.loadState then w:loadState(ws.state) end
            worlds[id] = w
        end
    end

    enterLocation(session.location, {keepPosition = true})
    currentState = world:tutorialActive() and gameState.TUTORIAL or gameState.PLAYING
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
        local ok, applyErr = pcall(applySaveState, data)
        if ok then
            titleMessage = nil
            return true
        end
        err = "save is damaged (" .. tostring(applyErr) .. ")"
        initializeGame()
        currentState = gameState.MENU
    end
    if ui and ui.showMenu then
        ui:showMenuMessage("Load failed: " .. tostring(err))
    end
    titleMessage = "Load failed: " .. tostring(err)
    return false
end

local function inGame()
    return currentState == gameState.PLAYING or currentState == gameState.TUTORIAL
end

-- Update game state
function love.update(dt)
    if inGame() then
        updateGame(dt)
    elseif currentState == gameState.MENU then
        updateMenu(dt)
    elseif currentState == gameState.PAUSED then
        updatePaused(dt)
    end
end

-- Draw game
function love.draw()
    if inGame() then
        drawGame()
    elseif currentState == gameState.MENU then
        drawMenu()
    elseif currentState == gameState.PAUSED then
        drawPaused()
    elseif currentState == gameState.STARMAP then
        starMap:draw()
    elseif currentState == gameState.SHOP then
        shop:draw()
    elseif currentState == gameState.DIALOGUE then
        drawGame()
        dialogue:draw()
    elseif currentState == gameState.ENDING then
        drawEnding()
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
    elseif currentState == gameState.STARMAP then
        if key == "left" or key == "a" or key == "up" or key == "w" then
            starMap:move(-1)
        elseif key == "right" or key == "d" or key == "down" or key == "s" then
            starMap:move(1)
        elseif key == "return" or key == "kpenter" or key == "space" then
            travelToSelected()
        elseif key == "escape" then
            currentState = gameState.PLAYING
        end
    elseif currentState == gameState.DIALOGUE then
        if key == "space" or key == "return" or key == "kpenter" or key == "e" then
            dialogue:advance()
        elseif key == "1" or key == "2" or key == "3" then
            dialogue:choose(tonumber(key))
        elseif key == "escape" then
            dialogue:skip()
        end
    elseif currentState == gameState.ENDING then
        if key == "return" or key == "space" or key == "kpenter" then
            initializeGame()
            currentState = gameState.MENU
        end
    elseif currentState == gameState.SHOP then
        if key == "up" or key == "w" then
            shop:move(-1)
        elseif key == "down" or key == "s" then
            shop:move(1)
        elseif key == "return" or key == "kpenter" or key == "space" then
            shop:buySelected()
        elseif key == "escape" then
            currentState = gameState.PLAYING
        end
    elseif key == "l" and currentState == gameState.MENU then
        loadSavedGame()
    elseif key == "escape" then
        if inGame() then
            stateBeforePause = currentState
            currentState = gameState.PAUSED
            ui:toggleMenu()
        elseif currentState == gameState.PAUSED then
            currentState = stateBeforePause
            ui:toggleMenu()
        end
    elseif key == "e" and inGame() then
        interact()
    elseif key == "i" and inGame() then
        ui:toggleInventory()
    elseif key == "m" and inGame() then
        ui:toggleMap()
    elseif key == "space" and currentState == gameState.MENU then
        -- New game: the intro plays, then the tutorial
        startDialogue(Story.intro, {returnState = world:tutorialActive() and gameState.TUTORIAL or gameState.PLAYING})
    elseif key == "r" and currentState == gameState.GAME_OVER then
        initializeGame()
        currentState = gameState.MENU
    elseif (key == "1" or key == "2" or key == "3" or key == "4" or key == "5") and inGame() then
        -- Weapons in the order the lore vault gives them (src/data/weapons.lua)
        local weaponId = Player.WEAPON_ORDER[tonumber(key)]
        if weaponId then player:switchWeapon(weaponId) end
    elseif (key == "6" or key == "7" or key == "8") and inGame() then
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

    if currentState == gameState.DIALOGUE then
        local choice = dialogue:choiceAt(x, y)
        if choice and button == 1 then
            dialogue:choose(choice)
        elseif button == 1 then
            dialogue:advance()
        end
        return
    end

    if currentState == gameState.SHOP then
        -- Click a row to select it; click the selected row again to buy
        local row = shop:rowAt(x, y)
        if row and button == 1 then
            if row == shop.selected then
                shop:buySelected()
            else
                shop.selected = row
                shop.message = nil
            end
        end
        return
    end

    if currentState == gameState.STARMAP then
        -- Click a node to select it; click the selected node again to jump
        local node = starMap:nodeAt(x, y)
        if node and button == 1 then
            if node == starMap.selected then
                travelToSelected()
            else
                starMap.selected = node
                starMap.message = nil
            end
        end
        return
    end

    if inGame() and ui.showInventory then
        -- Inventory open: click uses an item, right-click drops it; no firing
        local slot = ui:inventorySlotAt(x, y)
        if slot and button == 1 then
            player:useItem(slot)
        elseif slot and button == 2 then
            world:dropItem(player, slot)
        end
        return
    end

    if inGame() and button == 1 then
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

    -- Interaction prompt for the nearest usable object
    local obj = world:nearestInteractable(player.x, player.y)
    if obj and world:tutorialActive() then
        ui.prompt = (obj.label or "This") .. ": finish the tutorial first"
    else
        ui.prompt = obj and obj.prompt or nil
    end

    -- Update UI
    ui.objective = currentObjective()
    ui:update(dt)

    -- Check if tutorial is completed
    if currentState == gameState.TUTORIAL and world.tutorial.completed then
        currentState = gameState.PLAYING
        startDialogue(Story.afterTutorial)
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

    -- During the tutorial fight, point to enemies that fled off screen
    if world:tutorialActive() then
        for _, enemy in ipairs(world.enemies) do
            if enemy.isTutorialEnemy and not enemy.isDead then
                drawMarker(enemy.x, enemy.y, "Enemy", true)
            end
        end
    end
    
    -- Point the way to an unopened vault, or to the Arkadia
    if world.vault and not world.vault.collected and not world:tutorialActive() then
        drawMarker(world.vault.x, world.vault.y, "Vault")
    elseif world.arkadia then
        drawMarker(world.arkadia.x, world.arkadia.y, "Arkadia")
    end

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

-- Update menu state (the title screen is static)
function updateMenu(dt)
end

-- Draw menu
function drawMenu()
    -- Draw title screen
    love.graphics.setColor(1, 1, 1)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.print("The Last Starchart", w / 2 - 100, h / 2 - 50, 0, 2)
    love.graphics.print("Press SPACE to Start a New Game", w / 2 - 100, h / 2 + 50, 0, 1)
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

-- Draw the ending the player chose
function drawEnding()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local ending = Story.endings[endingId] or {title = "The End", text = ""}
    love.graphics.setColor(0.02, 0.03, 0.06)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 0.9, 0.5)
    love.graphics.printf(ending.title, 0, h / 2 - 160, w / 2, "center", 0, 2)
    love.graphics.setColor(1, 1, 1)
    local text = ending.text
    if ending.defiedVarro and session.flags.defied_varro then
        text = text .. " " .. ending.defiedVarro
    end
    love.graphics.printf(text, w / 2 - 320, h / 2 - 90, 640, "center")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Press Enter to return to the title screen", 0, h - 60, w, "center")
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
