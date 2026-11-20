local World = {}
World.__index = World

-- World configuration
local config = {
    tileSize = 32,
    chunkSize = 16,
    maxChunks = 3,
    enemySpawnChance = 0.3,
    maxEnemiesPerChunk = 5,
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
                text = "Use WASD to move and the mouse to aim. Left click to fire your weapon.",
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
                radius = 200
            },
            {
                type = "message",
                text = "Defeat these enemies to complete the tutorial!",
                duration = 10
            }
        },
        currentStep = 1,
        stepTimer = 0,
        completed = false
    }
}

function World.new()
    local self = setmetatable({}, World)
    
    -- World state
    self.chunks = {}
    self.currentChunk = {x = 0, y = 0}
    self.entities = {}
    self.enemies = {}
    self.loot = {}
    
    -- World generation settings
    self.seed = love.timer.getTime()
    self.biomeTypes = {
        JUNGLE = "jungle",
        DESERT = "desert",
        ICE = "ice",
        SPACE_STATION = "space_station"
    }
    
    -- Tutorial state
    self.tutorial = {
        enabled = config.tutorial.enabled,
        steps = config.tutorial.steps,
        currentStep = config.tutorial.currentStep,
        stepTimer = config.tutorial.stepTimer,
        completed = config.tutorial.completed
    }
    
    return self
end

function World:generateChunk(chunkX, chunkY)
    local chunk = {
        tiles = {},
        entities = {},
        biome = self:determineBiome(chunkX, chunkY)
    }
    
    -- Generate tiles based on biome
    for y = 1, config.chunkSize do
        chunk.tiles[y] = {}
        for x = 1, config.chunkSize do
            chunk.tiles[y][x] = self:generateTile(x, y, chunk.biome)
        end
    end
    
    -- Generate entities based on biome
    self:generateEntities(chunk)
    
    return chunk
end

function World:determineBiome(chunkX, chunkY)
    -- Simple biome determination based on position
    local value = (chunkX * 7 + chunkY * 13) % 4
    local biomes = {
        self.biomeTypes.JUNGLE,
        self.biomeTypes.DESERT,
        self.biomeTypes.ICE,
        self.biomeTypes.SPACE_STATION
    }
    return biomes[value + 1]
end

function World:generateTile(x, y, biome)
    -- TODO: Implement proper tile generation based on biome
    return {
        type = "floor",
        walkable = true,
        biome = biome
    }
end

function World:generateEntities(chunk)
    -- Generate enemies based on biome
    local enemyCount = 0
    while enemyCount < config.maxEnemiesPerChunk and math.random() < config.enemySpawnChance do
        local x = math.random(1, config.chunkSize) * config.tileSize
        local y = math.random(1, config.chunkSize) * config.tileSize
        
        -- Determine enemy type based on biome
        local enemyType
        if chunk.biome == self.biomeTypes.JUNGLE then
            enemyType = "ALIEN_WILDLIFE"
        elseif chunk.biome == self.biomeTypes.SPACE_STATION then
            enemyType = "ROBOTIC_DRONE"
        else
            enemyType = "SPACE_PIRATE"
        end
        
        local enemy = require("src.entities.enemy").new(x, y, enemyType)
        table.insert(chunk.entities, enemy)
        table.insert(self.enemies, enemy)
        enemyCount = enemyCount + 1
    end
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
    
    -- Check player projectiles against enemies
    for i = #player.projectiles, 1, -1 do
        local projectile = player.projectiles[i]
        local hit = false
        
        for _, enemy in ipairs(self.enemies) do
            if not enemy.isDead then
                local dx = projectile.x - enemy.x
                local dy = projectile.y - enemy.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance < 20 then -- Collision radius
                    enemy:takeDamage(projectile.damage)
                    table.remove(player.projectiles, i)
                    hit = true
                    break
                end
            end
        end
        
        if hit then break end
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
        if currentStep and currentStep.type == "message" then
            local alpha = 1 - (self.tutorial.stepTimer / currentStep.duration)
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