local World = {}
World.__index = World

-- World configuration
local bit = require("bit")

local config = {
    tileSize = 32,
    chunkSize = 16,
    maxChunks = 3,
    enemySpawnChance = 0.3,
    maxEnemiesPerChunk = 5,
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
    
    -- Update enemies
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if enemy.isDead then
            -- Create loot from enemy drops
            self:createLootFromEnemy(enemy)
            table.remove(self.enemies, i)
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
    
    -- Update current chunk if needed
    self:updateCurrentChunk()
    
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

function World:updateCurrentChunk()
    -- TODO: Implement chunk loading/unloading based on player position
end

function World:draw()
    -- Draw current chunk
    if self.chunks[self.currentChunk.x] and self.chunks[self.currentChunk.x][self.currentChunk.y] then
        local chunk = self.chunks[self.currentChunk.x][self.currentChunk.y]
        
        -- Draw tiles
        for y = 1, config.chunkSize do
            for x = 1, config.chunkSize do
                local tile = chunk.tiles[y][x]
                self:drawTile(x, y, tile)
            end
        end
    end
    
    -- Draw loot
    for _, item in ipairs(self.loot) do
        item:draw()
    end
    
    -- Draw enemies (chunk enemies are also tracked in self.enemies)
    for _, enemy in ipairs(self.enemies) do
        enemy:draw()
    end
    
    -- Draw world entities (player and its projectiles)
    for _, entity in ipairs(self.entities) do
        if entity.draw then
            entity:draw()
        end
    end
    
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

function World:drawTile(x, y, tile)
    -- TODO: Implement proper tile drawing
    local color = {
        [self.biomeTypes.JUNGLE] = {0, 1, 0},
        [self.biomeTypes.DESERT] = {1, 0.8, 0},
        [self.biomeTypes.ICE] = {0.8, 0.8, 1},
        [self.biomeTypes.SPACE_STATION] = {0.5, 0.5, 0.5}
    }
    
    love.graphics.setColor(unpack(color[tile.biome]))
    love.graphics.rectangle("fill", 
        (x - 1) * config.tileSize, 
        (y - 1) * config.tileSize, 
        config.tileSize, 
        config.tileSize
    )
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