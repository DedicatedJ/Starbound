local Player = {}
Player.__index = Player

-- Player configuration
local config = {
    moveSpeed = 200,
    maxHealth = 100,
    shieldRechargeRate = 5,
    shieldRechargeDelay = 2,
    inventorySize = 8,
    weapons = {
        laser_pistol = {
            name = "Laser Pistol",
            damage = 10,
            fireRate = 0.5,
            energyCost = 5,
            range = 300,
            projectileSpeed = 400,
            color = {0, 1, 1}, -- Cyan
            projectileSize = 5,
            effects = {
                trail = true,
                trailColor = {0, 1, 1, 0.5},
                trailLength = 10
            }
        },
        plasma_rifle = {
            name = "Plasma Rifle",
            damage = 20,
            fireRate = 0.3,
            energyCost = 10,
            range = 400,
            projectileSpeed = 500,
            color = {1, 0, 1}, -- Magenta
            projectileSize = 8,
            effects = {
                trail = true,
                trailColor = {1, 0, 1, 0.5},
                trailLength = 15,
                glow = true,
                glowColor = {1, 0, 1, 0.3}
            }
        },
        ion_cannon = {
            name = "Ion Cannon",
            damage = 35,
            fireRate = 1.0,
            energyCost = 25,
            range = 500,
            projectileSpeed = 300,
            color = {0, 0.8, 1}, -- Light Blue
            projectileSize = 12,
            effects = {
                trail = true,
                trailColor = {0, 0.8, 1, 0.5},
                trailLength = 20,
                glow = true,
                glowColor = {0, 0.8, 1, 0.4},
                charge = true,
                chargeTime = 0.5
            }
        },
        scatter_shot = {
            name = "Scatter Shot",
            damage = 8,
            fireRate = 0.4,
            energyCost = 15,
            range = 250,
            projectileSpeed = 350,
            color = {1, 0.5, 0}, -- Orange
            projectileSize = 4,
            projectileCount = 5,
            spreadAngle = math.pi / 6,
            effects = {
                trail = true,
                trailColor = {1, 0.5, 0, 0.5},
                trailLength = 8
            }
        },
        void_beam = {
            name = "Void Beam",
            damage = 15,
            fireRate = 0.2,
            energyCost = 20,
            range = 600,
            projectileSpeed = 600,
            color = {0.5, 0, 0.5}, -- Purple
            projectileSize = 6,
            effects = {
                trail = true,
                trailColor = {0.5, 0, 0.5, 0.5},
                trailLength = 25,
                glow = true,
                glowColor = {0.5, 0, 0.5, 0.3},
                pierce = true,
                pierceCount = 3
            }
        }
    }
}

function Player.new(x, y)
    local self = setmetatable({}, Player)
    
    -- Position
    self.x = x or 0
    self.y = y or 0
    
    -- Stats
    self.health = config.maxHealth
    self.maxHealth = config.maxHealth
    self.shield = config.maxHealth
    self.maxShield = config.maxHealth
    self.shieldRechargeTimer = 0
    self.energy = 100
    self.maxEnergy = 100
    self.energyRechargeRate = 10
    
    -- Inventory
    self.inventory = {}
    self.inventorySize = config.inventorySize
    
    -- Equipment
    self.currentWeapon = "laser_pistol"
    self.weapons = config.weapons
    self.fireTimer = 0
    self.projectiles = {}
    self.effects = {}
    
    -- Combat state
    self.isCharging = false
    self.chargeTimer = 0
    self.chargeReady = false
    self.lastFired = 0

    -- Aim point in world coordinates, set by the game each frame
    self.aimX = self.x
    self.aimY = self.y

    
    -- Movement
    self.velocity = {x = 0, y = 0}
    self.direction = {x = 0, y = 0}
    
    return self
end

function Player:update(dt)
    -- Update position based on velocity
    self.x = self.x + self.velocity.x * dt
    self.y = self.y + self.velocity.y * dt

-- Update shield recharge
    if self.shield < config.maxHealth then
        self.shieldRechargeTimer = self.shieldRechargeTimer + dt
        if self.shieldRechargeTimer >= config.shieldRechargeDelay then
            self.shield = math.min(config.maxHealth, self.shield + config.shieldRechargeRate * dt)
        end
    end
    
    -- Update energy recharge
    if self.energy < self.maxEnergy then
        self.energy = math.min(self.maxEnergy, self.energy + self.energyRechargeRate * dt)
    end
    
    -- Update fire timer
    if self.fireTimer > 0 then
        self.fireTimer = self.fireTimer - dt
    end
    
    -- Update charge timer; fire at the cursor once fully charged
    if self.isCharging then
        self.chargeTimer = self.chargeTimer + dt
        if self.chargeTimer >= self.weapons[self.currentWeapon].effects.chargeTime then
            self.isCharging = false
            self.chargeTimer = 0
            self.chargeReady = true
            self:fire(self.aimX, self.aimY)
            self.chargeReady = false
        end
    end
    
    -- Update projectiles
    for i = #self.projectiles, 1, -1 do
        local projectile = self.projectiles[i]
        projectile.x = projectile.x + projectile.dx * dt
        projectile.y = projectile.y + projectile.dy * dt
        
        -- Update trail effects
        if projectile.effects and projectile.effects.trail then
            table.insert(projectile.trail, {x = projectile.x, y = projectile.y})
            if #projectile.trail > projectile.effects.trailLength then
                table.remove(projectile.trail, 1)
            end
        end
        
        -- Remove projectiles that have traveled their maximum range
        local distance = math.sqrt((projectile.x - projectile.startX)^2 + (projectile.y - projectile.startY)^2)
        if distance >= projectile.range then
            table.remove(self.projectiles, i)
        end
    end
    
    -- Update combat effects
    for i = #self.effects, 1, -1 do
        local effect = self.effects[i]
        effect.lifetime = effect.lifetime - dt
        if effect.lifetime <= 0 then
            table.remove(self.effects, i)
        end
    end
end

function Player:move(dx, dy)
    -- Normalize so diagonal movement is not faster
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx, dy = dx / length, dy / length
    end

    self.velocity.x = dx * config.moveSpeed
    self.velocity.y = dy * config.moveSpeed
    
    -- Update direction for sprite/animation
    if dx ~= 0 or dy ~= 0 then
        self.direction.x = dx
        self.direction.y = dy
    end
end

function Player:takeDamage(amount)
    -- Shield absorbs damage first; any overflow goes to health
    local absorbed = math.min(self.shield, amount)
    self.shield = self.shield - absorbed
    self.health = math.max(0, self.health - (amount - absorbed))

    -- Any hit delays shield recharge
    self.shieldRechargeTimer = 0
end

function Player:heal(amount)
    self.health = math.min(config.maxHealth, self.health + amount)
end

function Player:addItem(item)
    if #self.inventory < self.inventorySize then
        table.insert(self.inventory, item)
        return true
    end
    return false
end

function Player:removeItem(index)
    if index >= 1 and index <= #self.inventory then
        table.remove(self.inventory, index)
        return true
    end
    return false
end

function Player:fire(targetX, targetY)
    if self.fireTimer > 0 or self.energy < self.weapons[self.currentWeapon].energyCost then
        return false
    end
    
    local weapon = self.weapons[self.currentWeapon]
    
    -- Charge weapons: a click starts the charge, and Player:update fires when it completes
    if weapon.effects.charge and not self.chargeReady then
        if not self.isCharging then
            self.isCharging = true
            self.chargeTimer = 0
        end
        return false
    end
    
    -- Calculate projectile direction
    local dx = targetX - self.x
    local dy = targetY - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        -- Handle scatter shot
        if weapon.projectileCount then
            for i = 1, weapon.projectileCount do
                local angle = math.atan2(dy, dx) + (i - (weapon.projectileCount + 1) / 2) * weapon.spreadAngle
                self:createProjectile(angle, weapon)
            end
        else
            -- Handle regular weapons
            self:createProjectile(math.atan2(dy, dx), weapon)
        end
        
        -- Add muzzle flash effect
        self:addEffect("muzzle_flash", self.x, self.y, math.atan2(dy, dx))
        
        self.energy = self.energy - weapon.energyCost
        self.fireTimer = weapon.fireRate
        self.lastFired = love.timer.getTime()
        
        return true
    end
    
    return false
end

function Player:createProjectile(angle, weapon)
    local projectile = {
        x = self.x,
        y = self.y,
        startX = self.x,
        startY = self.y,
        dx = math.cos(angle) * weapon.projectileSpeed,
        dy = math.sin(angle) * weapon.projectileSpeed,
        damage = weapon.damage,
        color = weapon.color,
        size = weapon.projectileSize,
        effects = weapon.effects,
        range = weapon.range,
        trail = {},
        pierceCount = weapon.effects.pierce and weapon.effects.pierceCount or 0,
        hitEnemies = {}
    }
    
    table.insert(self.projectiles, projectile)
end

function Player:addEffect(effectType, x, y, angle)
    local effect = {
        type = effectType,
        x = x,
        y = y,
        angle = angle,
        lifetime = 0.2,
        color = {1, 1, 1, 1}
    }
    
    table.insert(self.effects, effect)
end

function Player:switchWeapon(weaponName)
    if self.weapons[weaponName] then
        self.currentWeapon = weaponName
        -- Cancel any charge in progress so it does not carry over to another weapon
        self.isCharging = false
        self.chargeTimer = 0
        return true
    end
    return false
end

function Player:draw()
    -- Draw player
    love.graphics.setColor(0, 1, 0) -- Green
    love.graphics.circle("fill", self.x, self.y, 20)
    
    -- Draw health bar
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", self.x - 25, self.y - 30, 50 * (self.health / config.maxHealth), 5)
    
    -- Draw shield bar
    love.graphics.setColor(0, 0, 1)
    love.graphics.rectangle("fill", self.x - 25, self.y - 35, 50 * (self.shield / config.maxHealth), 5)
    
    -- Draw energy bar
    love.graphics.setColor(0, 1, 1)
    love.graphics.rectangle("fill", self.x - 25, self.y - 40, 50 * (self.energy / self.maxEnergy), 5)
    
    -- Draw projectiles and their effects
    for _, projectile in ipairs(self.projectiles) do
        -- Draw trail
        if projectile.effects.trail then
            love.graphics.setColor(unpack(projectile.effects.trailColor))
            for i = 1, #projectile.trail - 1 do
                local alpha = i / #projectile.trail
                love.graphics.setColor(projectile.effects.trailColor[1], projectile.effects.trailColor[2], 
                                     projectile.effects.trailColor[3], projectile.effects.trailColor[4] * alpha)
                love.graphics.line(projectile.trail[i].x, projectile.trail[i].y, 
                                 projectile.trail[i + 1].x, projectile.trail[i + 1].y)
            end
        end
        
        -- Draw projectile
        love.graphics.setColor(unpack(projectile.color))
        love.graphics.circle("fill", projectile.x, projectile.y, projectile.size)
        
        -- Draw glow effect
        if projectile.effects.glow then
            love.graphics.setColor(unpack(projectile.effects.glowColor))
            love.graphics.circle("fill", projectile.x, projectile.y, projectile.size * 1.5)
        end
    end
    
    -- Draw combat effects
    for _, effect in ipairs(self.effects) do
        if effect.type == "muzzle_flash" then
            local alpha = effect.lifetime / 0.2
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.circle("fill", effect.x, effect.y, 10)
        end
    end
    
    -- Draw charge effect
    if self.isCharging then
        local chargeProgress = self.chargeTimer / self.weapons[self.currentWeapon].effects.chargeTime
        love.graphics.setColor(1, 1, 0, 0.5)
        love.graphics.circle("line", self.x, self.y, 30 * chargeProgress)
    end
end

return Player 