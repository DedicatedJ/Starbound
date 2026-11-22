local Enemy = {}
Enemy.__index = Enemy

-- When true, enemies draw a ring showing their AI state (toggle with F3)
Enemy.debug = false

-- Numbers come from src/data (generated from the lore vault by tools/gen_data.py);
-- this file keeps behavior and looks.
local Balance = require("src.data.balance")
local EnemyData = require("src.data.enemies")

-- Each level above 1 adds this fraction to health and damage
local LEVEL_SCALING = Balance.enemies.levelScaling

-- How each enemy type looks and which AI it uses; stats are merged in below
local config = {
    types = {
        ALIEN_WILDLIFE = {color = {1, 0.5, 0}, behavior = {type = "aggressive"}}, -- Orange
        SPACE_PIRATE = {color = {0.8, 0, 0}, behavior = {type = "tactical"}},     -- Red
        ROBOTIC_DRONE = {color = {0.5, 0.5, 0.5}, behavior = {type = "swarm"}}    -- Gray
    }
}
for id, stats in pairs(EnemyData) do
    local enemyType = config.types[id]
    assert(enemyType, "enemy type " .. id .. " is in the lore vault but has no AI in src/entities/enemy.lua")
    for key, value in pairs(stats) do
        if key == "behavior" then
            for bkey, bvalue in pairs(value) do enemyType.behavior[bkey] = bvalue end
        else
            enemyType[key] = value
        end
    end
end
for id, enemyType in pairs(config.types) do
    assert(enemyType.health, "enemy type " .. id .. " has no stats in the lore vault")
end

function Enemy.new(x, y, enemyType, level)
    local self = setmetatable({}, Enemy)
    
    -- Position
    self.x = x or 0
    self.y = y or 0
    self.spawnX = x
    self.spawnY = y
    
    -- Stats
    self.type = enemyType or "ALIEN_WILDLIFE"
    self.stats = config.types[self.type]
    self.level = level or 1
    local scale = 1 + LEVEL_SCALING * (self.level - 1)
    self.health = self.stats.health * scale
    self.maxHealth = self.health
    
    -- Combat
    self.damage = self.stats.damage * scale
    self.attackRange = self.stats.attackRange
    self.attackCooldown = self.stats.attackCooldown
    self.attackTimer = 0
    
    -- Movement
    self.velocity = {x = 0, y = 0}
    self.moveSpeed = self.stats.moveSpeed
    self.target = nil
    
    -- AI state
    self.state = "patrol" -- patrol, chase, attack, retreat
    self.patrolAngle = math.random() * math.pi * 2
    self.strafeOffset = 0
    self.strafeDirection = 1
    
    -- Combat effects
    self.effects = {}
    self.hitFlash = 0
    
    -- State
    self.isDead = false
    
    return self
end

function Enemy:update(dt)
    if self.isDead then return end
    
    -- Update attack cooldown
    if self.attackTimer > 0 then
        self.attackTimer = self.attackTimer - dt
    end
    
    -- Update hit flash
    if self.hitFlash > 0 then
        self.hitFlash = self.hitFlash - dt
    end
    
    -- Update effects
    for i = #self.effects, 1, -1 do
        local effect = self.effects[i]
        effect.lifetime = effect.lifetime - dt
        if effect.lifetime <= 0 then
            table.remove(self.effects, i)
        end
    end
    
    -- Update AI behavior
    self:updateAI(dt)
    
    -- Apply movement
    self.x = self.x + self.velocity.x * dt
    self.y = self.y + self.velocity.y * dt

    -- Stay within a leash of the spawn point so retreating enemies can still be finished off
    local leash = self.stats.behavior.patrolRadius + self.stats.behavior.chaseRange
    local lx, ly = self.x - self.spawnX, self.y - self.spawnY
    local dist = math.sqrt(lx * lx + ly * ly)
    if dist > leash then
        self.x = self.spawnX + lx / dist * leash
        self.y = self.spawnY + ly / dist * leash
    end
end

function Enemy:setTarget(target)
    self.target = target
end

function Enemy:canAttack()
    if self.isDead or self.passive or not self.target or self.attackTimer > 0 then
        return false
    end
    local dx = self.target.x - self.x
    local dy = self.target.y - self.y
    return dx * dx + dy * dy <= self.attackRange * self.attackRange
end

function Enemy:performAttack()
    if self.target.takeDamage then
        self.target:takeDamage(self.damage)
    end
    self.attackTimer = self.attackCooldown
    self:addEffect("attack", self.target.x, self.target.y)
end

function Enemy:updateAI(dt)
    if not self.target then return end

    -- Passive enemies (pirates under Varro's truce) just patrol until provoked
    if self.passive then
        self.state = "patrol"
        self:patrol(dt)
        return
    end
    
    local dx = self.target.x - self.x
    local dy = self.target.y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Update state based on distance and health
    if self.health <= self.maxHealth * self.stats.behavior.retreatHealth then
        self.state = "retreat"
    elseif distance <= self.attackRange then
        self.state = "attack"
    elseif distance <= self.stats.behavior.chaseRange then
        self.state = "chase"
    else
        self.state = "patrol"
    end
    
    -- Handle different states
    if self.state == "patrol" then
        self:patrol(dt)
    elseif self.state == "chase" then
        self:chase(dt)
    elseif self.state == "attack" then
        self:attackState(dt)
    elseif self.state == "retreat" then
        self:retreat(dt)
    end
end

function Enemy:patrol(dt)
    -- Move in a circular pattern around spawn point
    self.patrolAngle = self.patrolAngle + dt * 0.5
    local radius = self.stats.behavior.patrolRadius
    
    local targetX = self.spawnX + math.cos(self.patrolAngle) * radius
    local targetY = self.spawnY + math.sin(self.patrolAngle) * radius
    
    local dx = targetX - self.x
    local dy = targetY - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        self.velocity.x = (dx / distance) * self.moveSpeed
        self.velocity.y = (dy / distance) * self.moveSpeed
    end
end

function Enemy:chase(dt)
    local dx = self.target.x - self.x
    local dy = self.target.y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        -- Handle different behavior types
        if self.stats.behavior.type == "tactical" then
            -- Strafe while chasing
            self.strafeOffset = self.strafeOffset + dt * self.stats.behavior.strafeSpeed * self.strafeDirection
            if math.abs(self.strafeOffset) > self.stats.behavior.strafeRange then
                self.strafeDirection = -self.strafeDirection
            end
            
            local strafeX = -dy * (self.strafeOffset / self.stats.behavior.strafeRange)
            local strafeY = dx * (self.strafeOffset / self.stats.behavior.strafeRange)
            
            self.velocity.x = (dx / distance) * self.moveSpeed + strafeX
            self.velocity.y = (dy / distance) * self.moveSpeed + strafeY
        else
            self.velocity.x = (dx / distance) * self.moveSpeed
            self.velocity.y = (dy / distance) * self.moveSpeed
        end
    end
end

function Enemy:attackState(dt)
    -- Stop moving when in attack range
    self.velocity.x = 0
    self.velocity.y = 0
    
    if self:canAttack() then
        self:performAttack()
    end
end

function Enemy:retreat(dt)
    local dx = self.x - self.target.x
    local dy = self.y - self.target.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        self.velocity.x = (dx / distance) * self.moveSpeed * 1.5
        self.velocity.y = (dy / distance) * self.moveSpeed * 1.5
    end
end

function Enemy:takeDamage(amount)
    self.passive = false   -- being shot ends any truce
    self.health = math.max(0, self.health - amount)
    self.hitFlash = 0.2
    
    -- Add hit effect
    self:addEffect("hit", self.x, self.y)
    
    if self.health <= 0 then
        self.isDead = true
        -- Loot is dropped by World:createLootFromEnemy when the enemy is removed
    end
end

function Enemy:addEffect(effectType, x, y)
    local effect = {
        type = effectType,
        x = x,
        y = y,
        lifetime = 0.2,
        color = {1, 0, 0, 1}
    }
    
    table.insert(self.effects, effect)
end

function Enemy:draw()
    if self.isDead then return end
    
    -- Draw enemy with hit flash
    if self.hitFlash > 0 then
        love.graphics.setColor(1, 1, 1, self.hitFlash / 0.2)
    else
        love.graphics.setColor(unpack(self.stats.color))
    end
    love.graphics.circle("fill", self.x, self.y, 15)
    
    -- Draw health bar
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", self.x - 20, self.y - 25, 40 * (self.health / self.maxHealth), 5)
    
    -- Draw effects
    for _, effect in ipairs(self.effects) do
        local alpha = effect.lifetime / 0.2
        if effect.type == "hit" then
            love.graphics.setColor(1, 0, 0, alpha)
            love.graphics.circle("line", effect.x, effect.y, 20)
        elseif effect.type == "attack" then
            love.graphics.setColor(1, 0.3, 0.3, alpha)
            love.graphics.line(self.x, self.y, effect.x, effect.y)
        end
    end
    
    -- Level label for tougher enemies
    if self.level > 1 then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print("Lv" .. self.level, self.x - 10, self.y - 40)
    end

    -- Draw state indicator (debug only)
    if Enemy.debug and self.target then
        local stateColors = {
            patrol = {0, 1, 0},
            chase = {1, 1, 0},
            attack = {1, 0, 0},
            retreat = {0, 0, 1}
        }
        love.graphics.setColor(unpack(stateColors[self.state]))
        love.graphics.circle("line", self.x, self.y, 20)
    end
end

return Enemy 