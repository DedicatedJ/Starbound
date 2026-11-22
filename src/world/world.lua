local World = {}
World.__index = World

-- World configuration
local bit = require("bit")
local Enemy = require("src.entities.enemy")

local config = {
    tileSize = 32,
    chunkSize = 16,
    maxChunks = 3,
    enemySpawnChance = 0.3,
    maxEnemiesPerChunk = 5,
    activeRadius = 1,   -- chunks within this distance of the player have live enemies
    unloadRadius = 2,   -- enemies in chunks farther than this are despawned
    chunksPerLevel = 2, -- enemy level rises by 1 for every this many chunks from the start
-- Biome look and inhabitants; a world picks a subset of these
    biomes = {
        jungle = {
            floor = {0.13, 0.42, 0.18}, alt = {0.11, 0.36, 0.15}, decor = {0.22, 0.58, 0.26},
            enemies = {"ALIEN_WILDLIFE"}
        },
        desert = {
            floor = {0.72, 0.58, 0.32}, alt = {0.66, 0.52, 0.28}, decor = {0.52, 0.40, 0.21},
            enemies = {"SPACE_PIRATE", "ALIEN_WILDLIFE"}
        },
        ice = {
            floor = {0.76, 0.82, 0.90}, alt = {0.68, 0.76, 0.86}, decor = {0.58, 0.68, 0.84},
            enemies = {"SPACE_PIRATE"}
        },
        space_station = {
            floor = {0.30, 0.32, 0.36}, alt = {0.26, 0.28, 0.32}, decor = {0.45, 0.50, 0.55},
            enemies = {"ROBOTIC_DRONE"}
        }
    },
    tutorial = {
        enabled = true,
        steps = {
            {
                type = "message",
                text = "Welcome to Starbound Legacy! Let's learn the basics of combat.",
                duration = 5
            },
            {
                type = "message",
                text = "Use WASD or the arrow keys to move and the mouse to aim. Left click to fire.",
                duration = 5
            },
            {
                type = "message",
                text = "Press 1-5 to switch between different weapons. Each weapon has unique properties.",
                duration = 5
            },
            {
                type = "message",
                text = "Watch your energy bar - weapons consume energy when fired.",
                duration = 5
            },
            {
                type = "message",
                text = "Enemies drop loot when defeated. Collect health and energy crystals to stay alive.",
                duration = 5
            },
            {
                type = "message",
                text = "Your shield recharges when not taking damage. Use it wisely!",
                duration = 5
            },
            {
                type = "spawn",
                enemyType = "ALIEN_WILDLIFE",
                count = 3,
                radius = 200,
                text = "Defeat these enemies to complete the tutorial!"
            },
            {
                type = "message",
                text = "Tutorial complete! Good luck out there.",
                duration = 4
            }
        },
        currentStep = 1,
        stepTimer = 0,
        completed = false
    }
}

function World.new(options)
    options = options or {}
    local self = setmetatable({}, World)

    -- World state
    self.chunks = {}
    self.currentChunk = {x = 0, y = 0}
    self.entities = {}
    self.enemies = {}
    self.loot = {}
    self.explored = {}          -- chunk keys the player has visited (for the map)
    self.startChunkKey = nil    -- the chunk the player starts in has no enemies
    self.spawnEnemies = options.spawnEnemies ~= false
    self.clearedKeys = {}       -- chunk keys cleared in a loaded save
    self.levelBonus = options.levelBonus or 0
    self.bounds = options.bounds          -- {x0, y0, x1, y1} in world pixels, or nil for open worlds
    self.interactables = {}               -- objects the player can use with E

    -- The seed drives all procedural generation, so a world can be rebuilt exactly from it
    self.seed = options.seed or love.math.random(1, 2147483646)
    self.biomeList = options.biomes or {"jungle", "desert", "ice", "space_station"}
    self.biomeTypes = {
        JUNGLE = "jungle",
        DESERT = "desert",
        ICE = "ice",
        SPACE_STATION = "space_station"
    }

    -- Tutorial state
    self.tutorial = {
        enabled = config.tutorial.enabled and options.tutorial ~= false,
        steps = config.tutorial.steps,
        currentStep = config.tutorial.currentStep,
        stepTimer = config.tutorial.stepTimer,
        completed = config.tutorial.completed
    }

    return self
end

-- Main color of a biome, used by the map
function World.biomeColor(biome)
    return config.biomes[biome] and config.biomes[biome].floor or {0.5, 0.5, 0.5}
end

-- Where the ship lands: the center of chunk (0,0)
function World.landingSite()
    local half = config.tileSize * config.chunkSize / 2
    return half, half
end

-- Bounds covering the chunks within `radius` of chunk (0,0)
function World.chunkBounds(radius)
    local size = config.tileSize * config.chunkSize
    return {x0 = -radius * size, y0 = -radius * size, x1 = (radius + 1) * size, y1 = (radius + 1) * size}
end

-- Size of one chunk in world pixels
function World.chunkPixels()
    return config.tileSize * config.chunkSize
end

function World.chunkKey(chunkX, chunkY)
    return chunkX .. "," .. chunkY
end

-- Random generator that depends only on the world seed and the chunk position
function World:chunkRandom(chunkX, chunkY)
    local h = bit.bxor(bit.tobit(self.seed), bit.tobit(chunkX * 19349663), bit.tobit(chunkY * 83492791))
    h = bit.bxor(h, bit.rshift(h, 13))
    h = bit.tobit(h * 1274126177)
    return love.math.newRandomGenerator(bit.band(h, 0x7fffffff) + 1)
end

function World:generateChunk(chunkX, chunkY)
    local rng = self:chunkRandom(chunkX, chunkY)
    local chunk = {
        x = chunkX,
        y = chunkY,
        key = World.chunkKey(chunkX, chunkY),
        tiles = {},
        entities = {},
        enemySpawns = {},
        biome = self:determineBiome(chunkX, chunkY)
    }

    -- Tiles: mostly floor, some alternate floor, a little decoration
    for y = 1, config.chunkSize do
        chunk.tiles[y] = {}
        for x = 1, config.chunkSize do
            local r = rng:random()
            local tileType = (r < 0.08 and "decor") or (r < 0.4 and "alt") or "floor"
            chunk.tiles[y][x] = {type = tileType, walkable = true, biome = chunk.biome}
        end
    end

    -- Enemy spawn points in world coordinates; enemies are created when the chunk becomes active
    local originX, originY = chunkX * World.chunkPixels(), chunkY * World.chunkPixels()
    local inhabitants = config.biomes[chunk.biome].enemies
    while #chunk.enemySpawns < config.maxEnemiesPerChunk and rng:random() < config.enemySpawnChance do
        table.insert(chunk.enemySpawns, {
            x = originX + (rng:random(1, config.chunkSize) - 0.5) * config.tileSize,
            y = originY + (rng:random(1, config.chunkSize) - 0.5) * config.tileSize,
            enemyType = inhabitants[rng:random(1, #inhabitants)]
        })
    end

    return chunk
end

function World:determineBiome(chunkX, chunkY)
    -- Smooth noise so neighbouring chunks tend to share a biome
    local n = love.math.noise(chunkX * 0.3 + (self.seed % 1000) + 0.37, chunkY * 0.3 + (self.seed % 997) + 0.61)
    local index = math.min(#self.biomeList, math.floor(n * #self.biomeList) + 1)
    return self.biomeList[index]
end

function World:update(dt)
    -- Update tutorial
    if self.tutorial.enabled and not self.tutorial.completed then
        self:updateTutorial(dt)
    end
    
    -- Update all entities
    for _, entity in ipairs(self.entities) do
        if entity.update then
            entity:update(dt)
        end
    end
    
    -- Keep the player inside bounded areas (space station decks)
    if self.bounds then
        local player = self:findPlayer()
        if player then
            player.x = math.max(self.bounds.x0 + 20, math.min(self.bounds.x1 - 20, player.x))
            player.y = math.max(self.bounds.y0 + 20, math.min(self.bounds.y1 - 20, player.y))
        end
    end

    -- Update interactables that animate (puzzles)
    for _, obj in ipairs(self.interactables) do
        if obj.update then obj:update(dt, self) end
    end

    -- Update enemies
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if enemy.isDead then
            -- Create loot from enemy drops
            self:createLootFromEnemy(enemy)
            table.remove(self.enemies, i)
            self:onEnemyRemoved(enemy)
        else
            -- Set player as target for enemies
            local player = self:findPlayer()
            if player then
                enemy:setTarget(player)
            end
            enemy:update(dt)
        end
    end
    
    -- Update loot
    for i = #self.loot, 1, -1 do
        local item = self.loot[i]
        if item.isCollected then
            table.remove(self.loot, i)
        else
            item:update(dt)
            
            -- Check for player collection
            local player = self:findPlayer()
            if player then
                local dx = player.x - item.x
                local dy = player.y - item.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance < 30 then
                    item:applyEffect(player)
                end
            end
        end
    end
    
    -- Keep drone formations spread out
    self:applySwarmSpacing()

    -- Stream chunks around the player
    self:updateChunks()
    
    -- Check for combat interactions
    self:checkCombat()
end

function World:updateTutorial(dt)
    local currentStep = self.tutorial.steps[self.tutorial.currentStep]
    if not currentStep then
        self.tutorial.completed = true
        return
    end
    
    self.tutorial.stepTimer = self.tutorial.stepTimer + dt
    
    if currentStep.type == "spawn" then
        -- Check if all tutorial enemies are defeated
        local tutorialEnemies = 0
        for _, enemy in ipairs(self.enemies) do
            if enemy.isTutorialEnemy then
                tutorialEnemies = tutorialEnemies + 1
            end
        end
        
        if tutorialEnemies == 0 then
            self:nextTutorialStep()
        end
    elseif self.tutorial.stepTimer >= currentStep.duration then
        self:nextTutorialStep()
    end
end

function World:nextTutorialStep()
    self.tutorial.currentStep = self.tutorial.currentStep + 1
    self.tutorial.stepTimer = 0
    
    local nextStep = self.tutorial.steps[self.tutorial.currentStep]
    if nextStep and nextStep.type == "spawn" then
        -- Spawn tutorial enemies
        for i = 1, nextStep.count do
            local angle = (i / nextStep.count) * math.pi * 2
            local x = self:findPlayer().x + math.cos(angle) * nextStep.radius
            local y = self:findPlayer().y + math.sin(angle) * nextStep.radius
            
            local enemy = require("src.entities.enemy").new(x, y, nextStep.enemyType)
            enemy.isTutorialEnemy = true
            table.insert(self.enemies, enemy)
        end
    end
end

function World:createLootFromEnemy(enemy)
    for _, drop in ipairs(enemy.stats.drops) do
        if math.random() < drop.chance then
            local Loot = require("src.entities.loot")
            local loot = Loot.new(enemy.x, enemy.y, drop.item)
            table.insert(self.loot, loot)
        end
    end
end

-- Drop one item from the player's inventory onto the ground nearby
function World:dropItem(player, index)
    local itemType = player:removeItem(index)
    if not itemType then return false end
    local Loot = require("src.entities.loot")
    local loot = Loot.new(player.x, player.y, itemType)
    loot.pickupDelay = 1.5   -- so it is not picked straight back up
    table.insert(self.loot, loot)
    return true
end

function World:findPlayer()
    for _, entity in ipairs(self.entities) do
        if entity.__index == require("src.entities.player") then
            return entity
        end
    end
    return nil
end

function World:checkCombat()
    local player = self:findPlayer()
    if not player then return end
    
    -- Check every player projectile against enemies
    for i = #player.projectiles, 1, -1 do
        local projectile = player.projectiles[i]

        for _, enemy in ipairs(self.enemies) do
            -- A piercing projectile damages each enemy at most once
            if not enemy.isDead and not projectile.hitEnemies[enemy] then
                local dx = projectile.x - enemy.x
                local dy = projectile.y - enemy.y
                local radius = 15 + projectile.size -- enemy radius + projectile radius

                if dx * dx + dy * dy < radius * radius then
                    enemy:takeDamage(projectile.damage)
                    projectile.hitEnemies[enemy] = true

                    if projectile.pierceCount > 0 then
                        projectile.pierceCount = projectile.pierceCount - 1
                    else
                        table.remove(player.projectiles, i)
                        break
                    end
                end
            end
        end
    end
    
    -- Enemy attacks against the player are handled in Enemy:attackState
end

function World.worldToChunk(x, y)
    local size = World.chunkPixels()
    return math.floor(x / size), math.floor(y / size)
end

-- Return a chunk, generating and caching it on first use
function World:getChunk(chunkX, chunkY)
    local key = World.chunkKey(chunkX, chunkY)
    local chunk = self.chunks[key]
    if not chunk then
        chunk = self:generateChunk(chunkX, chunkY)
        chunk.cleared = self.clearedKeys[key] or nil
        self.chunks[key] = chunk
    end
    return chunk
end

function World:tutorialActive()
    return self.tutorial.enabled and not self.tutorial.completed
end

-- Activate chunks near the player and despawn enemies in chunks far away
function World:updateChunks()
    local player = self:findPlayer()
    if not player then return end

    local pcx, pcy = World.worldToChunk(player.x, player.y)
    self.currentChunk.x, self.currentChunk.y = pcx, pcy
    local here = World.chunkKey(pcx, pcy)
    if not self.startChunkKey then
        self.startChunkKey = here
        self.startChunk = {x = pcx, y = pcy}
    end
    self.explored[here] = true

    for cy = pcy - config.activeRadius, pcy + config.activeRadius do
        for cx = pcx - config.activeRadius, pcx + config.activeRadius do
            local chunk = self:getChunk(cx, cy)
            chunk.active = true
            self.explored[chunk.key] = true   -- seen chunks appear on the map
            if not chunk.spawned and not chunk.cleared then
                self:spawnChunkEnemies(chunk)
            end
        end
    end

    for key, chunk in pairs(self.chunks) do
        if chunk.active and (math.abs(chunk.x - pcx) > config.unloadRadius or math.abs(chunk.y - pcy) > config.unloadRadius) then
            chunk.active = false
            chunk.spawned = false
            chunk.enemiesAlive = 0
            for i = #self.enemies, 1, -1 do
                if self.enemies[i].chunkKey == key then
                    table.remove(self.enemies, i)
                end
            end
        end
    end
end

function World:spawnChunkEnemies(chunk)
    -- No spawns while the tutorial runs, in the safe start chunk, or when disabled
    if not self.spawnEnemies or self:tutorialActive() or chunk.key == self.startChunkKey then
        return
    end
    chunk.spawned = true
    chunk.enemiesAlive = 0
    local level = self:levelForChunk(chunk.x, chunk.y)
    for _, spawn in ipairs(chunk.enemySpawns) do
        local enemy = Enemy.new(spawn.x, spawn.y, spawn.enemyType, level)
        enemy.chunkKey = chunk.key
        table.insert(self.enemies, enemy)
        chunk.enemiesAlive = chunk.enemiesAlive + 1
    end
    if chunk.enemiesAlive == 0 then
        chunk.cleared = true
    end
end

-- Enemies get tougher the farther a chunk is from where the player started
function World:levelForChunk(chunkX, chunkY)
    local start = self.startChunk or {x = 0, y = 0}
    local distance = math.max(math.abs(chunkX - start.x), math.abs(chunkY - start.y))
    return 1 + self.levelBonus + math.floor(distance / config.chunksPerLevel)
end

-- Swarm enemies (drones) push apart to keep their formation spacing
function World:applySwarmSpacing()
    for i = 1, #self.enemies do
        local a = self.enemies[i]
        local spacing = a.stats.behavior.formationSpacing
        if spacing and not a.isDead then
            for j = i + 1, #self.enemies do
                local b = self.enemies[j]
                if b.stats.behavior.formationSpacing and not b.isDead then
                    local dx, dy = b.x - a.x, b.y - a.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < spacing then
                        if dist < 0.001 then
                            -- Exactly overlapping: separate along a fixed axis
                            dx, dy, dist = 1, 0, 1
                        end
                        local push = (spacing - dist) / 2
                        a.x, a.y = a.x - dx / dist * push, a.y - dy / dist * push
                        b.x, b.y = b.x + dx / dist * push, b.y + dy / dist * push
                    end
                end
            end
        end
    end
end

-- A chunk whose enemies are all defeated stays cleared and never respawns
function World:onEnemyRemoved(enemy)
    local chunk = enemy.chunkKey and self.chunks[enemy.chunkKey]
    if chunk then
        chunk.enemiesAlive = (chunk.enemiesAlive or 1) - 1
        if chunk.enemiesAlive <= 0 then
            chunk.cleared = true
        end
    end
end

-- Draw the world; the view rectangle (world coordinates) selects which chunks' tiles to draw
function World:draw(viewX0, viewY0, viewX1, viewY1)
    if viewX0 then
        local cx0, cy0 = World.worldToChunk(viewX0, viewY0)
        local cx1, cy1 = World.worldToChunk(viewX1, viewY1)
        for cy = cy0, cy1 do
            for cx = cx0, cx1 do
                self:drawChunk(self:getChunk(cx, cy))
            end
        end
    end

    -- Draw loot
    for _, item in ipairs(self.loot) do
        item:draw()
    end

    -- Draw interactables (ship, people, terminals, puzzles)
    for _, obj in ipairs(self.interactables) do
        World.drawInteractable(obj)
    end

    -- Draw enemies
    for _, enemy in ipairs(self.enemies) do
        enemy:draw()
    end

    -- Draw world entities (player and its projectiles)
    for _, entity in ipairs(self.entities) do
        if entity.draw then
            entity:draw()
        end
    end
end

-- Screen-space overlays drawn after the camera transform is removed
function World:drawOverlay()
    -- Draw tutorial message
    if self.tutorial.enabled and not self.tutorial.completed then
        local currentStep = self.tutorial.steps[self.tutorial.currentStep]
        if currentStep and currentStep.text then
            -- Timed messages fade out; the spawn step's text stays until the enemies are defeated
            local alpha = 1
            if currentStep.duration then
                alpha = 1 - (self.tutorial.stepTimer / currentStep.duration)
            end
            love.graphics.setColor(1, 1, 1, alpha)
            -- Drawn below the HUD so the two do not overlap
            love.graphics.print(currentStep.text, 20, 130, 0, 1.5)
        end
    end
end

function World:drawChunk(chunk)
    -- Outside a bounded area there is only open space
    if self.bounds then
        local size = World.chunkPixels()
        local x0, y0 = chunk.x * size, chunk.y * size
        if x0 >= self.bounds.x1 or y0 >= self.bounds.y1 or x0 + size <= self.bounds.x0 or y0 + size <= self.bounds.y0 then
            love.graphics.setColor(0.03, 0.03, 0.07)
            love.graphics.rectangle("fill", x0, y0, size, size)
            return
        end
    end
    local colors = config.biomes[chunk.biome]
    local size = config.tileSize
    local originX, originY = chunk.x * World.chunkPixels(), chunk.y * World.chunkPixels()
    for y = 1, config.chunkSize do
        local row = chunk.tiles[y]
        for x = 1, config.chunkSize do
            local tile = row[x]
            local px, py = originX + (x - 1) * size, originY + (y - 1) * size
            love.graphics.setColor(tile.type == "alt" and colors.alt or colors.floor)
            love.graphics.rectangle("fill", px, py, size, size)
            if tile.type == "decor" then
                love.graphics.setColor(colors.decor)
                love.graphics.circle("fill", px + size / 2, py + size / 2, size * 0.3)
            end
        end
    end
end

-- Interactables: tables with x, y, radius, prompt, onInteract(obj) and optional
-- kind/color/label/draw/update fields
function World:addInteractable(obj)
    obj.radius = obj.radius or 60
    table.insert(self.interactables, obj)
    return obj
end

function World:removeInteractable(obj)
    for i, other in ipairs(self.interactables) do
        if other == obj then
            table.remove(self.interactables, i)
            return true
        end
    end
    return false
end

function World:findInteractable(id)
    for _, obj in ipairs(self.interactables) do
        if obj.id == id then return obj end
    end
    return nil
end

-- Closest usable interactable within its radius of a point, or nil
function World:nearestInteractable(x, y)
    local best, bestDist
    for _, obj in ipairs(self.interactables) do
        if obj.onInteract and not obj.disabled then
            local d = math.sqrt((obj.x - x) ^ 2 + (obj.y - y) ^ 2)
            if d <= obj.radius and (not bestDist or d < bestDist) then
                best, bestDist = obj, d
            end
        end
    end
    return best
end

function World.drawInteractable(obj)
    if obj.draw then
        obj:draw()
    elseif obj.kind == "ship" then
        love.graphics.setColor(0.75, 0.78, 0.85)
        love.graphics.polygon("fill", obj.x, obj.y - 34, obj.x - 24, obj.y + 26, obj.x + 24, obj.y + 26)
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.circle("fill", obj.x, obj.y - 4, 7)
        love.graphics.setColor(1, 0.6, 0.2)
        love.graphics.rectangle("fill", obj.x - 14, obj.y + 26, 8, 6)
        love.graphics.rectangle("fill", obj.x + 6, obj.y + 26, 8, 6)
    elseif obj.kind == "terminal" then
        love.graphics.setColor(0.25, 0.25, 0.3)
        love.graphics.rectangle("fill", obj.x - 18, obj.y - 24, 36, 48)
        love.graphics.setColor(obj.color or {0.3, 1, 0.6})
        love.graphics.rectangle("fill", obj.x - 13, obj.y - 19, 26, 18)
    else
        love.graphics.setColor(obj.color or {1, 1, 1})
        love.graphics.circle("fill", obj.x, obj.y, obj.size or 16)
    end
    if obj.label then
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(obj.label, obj.x - 80, obj.y - 58, 160, "center")
    end
end

function World:addEntity(entity)
    table.insert(self.entities, entity)
end

function World:removeEntity(entity)
    for i, e in ipairs(self.entities) do
        if e == entity then
            table.remove(self.entities, i)
            break
        end
    end
end

return World 