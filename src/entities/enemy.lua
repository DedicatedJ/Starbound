local Enemy = {}
Enemy.__index = Enemy

-- Enemy configuration
local config = {
    types = {
        ALIEN_WILDLIFE = {
            name = "Alien Wildlife",
            health = 50,
            damage = 10,
            moveSpeed = 100,
            attackRange = 100,
            attackCooldown = 1.0,
            color = {1, 0.5, 0}, -- Orange
            drops = {
                {item = "health_crystal", chance = 0.3},
                {item = "energy_crystal", chance = 0.2},
                {item = "alien_essence", chance = 0.1}
            },
            behavior = {
                type = "aggressive",
                patrolRadius = 200,
                chaseRange = 300,
                retreatHealth = 0.3
            }
        },
        SPACE_PIRATE = {
            name = "Space Pirate",
            health = 75,
            damage = 15,
            moveSpeed = 150,
            attackRange = 150,
            attackCooldown = 0.8,
            color = {0.8, 0, 0}, -- Red
            drops = {
                {item = "health_crystal", chance = 0.4},
                {item = "energy_crystal", chance = 0.3},
                {item = "weapon_upgrade", chance = 0.15},
                {item = "shield_crystal", chance = 0.1}
            },
            behavior = {
                type = "tactical",
                patrolRadius = 300,
                chaseRange = 400,
                retreatHealth = 0.4,
                strafeSpeed = 100,
                strafeRange = 100
            }
        },
        ROBOTIC_DRONE = {
            name = "Robotic Drone",
            health = 40,
            damage = 8,
            moveSpeed = 200,
            attackRange = 120,
            attackCooldown = 0.5,
            color = {0.5, 0.5, 0.5}, -- Gray
            drops = {
                {item = "energy_crystal", chance = 0.5},
                {item = "weapon_upgrade", chance = 0.2},
                {item = "shield_crystal", chance = 0.15},
                {item = "repair_kit", chance = 0.1}
            },
            behavior = {
                type = "swarm",
                patrolRadius = 150,
                chaseRange = 250,
                retreatHealth = 0.2,
                formationSpacing = 50
            }
        }
    }
}

function Enemy.new(x, y, enemyType)
    local self = setmetatable({}, Enemy)
    
    -- Position
    self.x = x or 0
    self.y = y or 0
    self.spawnX = x
    self.spawnY = y
    
    -- Stats
    self.type = enemyType or "ALIEN_WILDLIFE"
    self.stats = config.types[self.type]
    self.health = self.stats.health
    self.maxHealth = self.stats.health
    
    -- Combat
    self.damage = self.stats.damage
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

    -- Keep enemies on screen so retreating ones can still be finished off
    self.x = math.max(15, math.min(love.graphics.getWidth() - 15, self.x))
    self.y = math.max(15, math.min(love.graphics.getHeight() - 15, self.y))
end

function Enemy:setTarget(target)
    self.target = target
end

function Enemy:canAttack()
    if self.isDead or not self.target or self.attackTimer > 0 then
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
    
    -- Draw state indicator (for debugging)
    if self.target then
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