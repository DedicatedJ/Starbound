local Loot = {}
Loot.__index = Loot

-- Loot configuration
local config = {
    items = {
        health_crystal = {
            name = "Health Crystal",
            type = "consumable",
            effect = "heal",
            value = 25,
            color = {1, 0, 0, 1},
            size = 10,
            lifetime = 30,
            effects = {
                glow = true,
                glowColor = {1, 0, 0, 0.3},
                pulse = true,
                pulseSpeed = 2,
                pulseScale = 0.2
            }
        },
        energy_crystal = {
            name = "Energy Crystal",
            type = "consumable",
            effect = "energy",
            value = 25,
            color = {0, 1, 1, 1},
            size = 10,
            lifetime = 30,
            effects = {
                glow = true,
                glowColor = {0, 1, 1, 0.3},
                pulse = true,
                pulseSpeed = 2,
                pulseScale = 0.2
            }
        },
        shield_crystal = {
            name = "Shield Crystal",
            type = "consumable",
            effect = "shield",
            value = 25,
            color = {0, 0, 1, 1},
            size = 10,
            lifetime = 30,
            effects = {
                glow = true,
                glowColor = {0, 0, 1, 0.3},
                pulse = true,
                pulseSpeed = 2,
                pulseScale = 0.2
            }
        },
        weapon_upgrade = {
            name = "Weapon Upgrade",
            type = "upgrade",
            effect = "damage",
            value = 5,
            color = {1, 1, 0, 1},
            size = 12,
            lifetime = 60,
            effects = {
                glow = true,
                glowColor = {1, 1, 0, 0.3},
                rotate = true,
                rotateSpeed = 2
            }
        },
        repair_kit = {
            name = "Repair Kit",
            type = "consumable",
            effect = "repair",
            value = 50,
            color = {0.5, 0.5, 0.5, 1},
            size = 12,
            lifetime = 60,
            effects = {
                glow = true,
                glowColor = {0.5, 0.5, 0.5, 0.3},
                pulse = true,
                pulseSpeed = 1,
                pulseScale = 0.1
            }
        },
        salvage = {
            name = "Salvage",
            type = "material",
            effect = "craft",
            value = 50,
            color = {0.55, 0.65, 0.75, 1},
            size = 11,
            lifetime = 120,
            effects = {
                glow = true,
                glowColor = {0.55, 0.65, 0.75, 0.3},
                rotate = true,
                rotateSpeed = 1.5
            }
        },
        alien_essence = {
            name = "Alien Essence",
            type = "material",
            effect = "craft",
            value = 100,
            color = {0.5, 0, 0.5, 1},
            size = 15,
            lifetime = 120,
            effects = {
                glow = true,
                glowColor = {0.5, 0, 0.5, 0.3},
                pulse = true,
                pulseSpeed = 1.5,
                pulseScale = 0.3,
                rotate = true,
                rotateSpeed = 1
            }
        }
    }
}

function Loot.new(x, y, itemType)
    local self = setmetatable({}, Loot)
    
    -- Position
    self.x = x
    self.y = y
    
    -- Item properties
    self.type = itemType
    self.item = config.items[itemType]
    self.lifetime = self.item.lifetime
    self.rotation = 0
    
    -- Movement: a short burst away from the drop point that slows to a stop
    local angle = math.random() * math.pi * 2
    local speed = 40 + math.random() * 40
    self.velocity = {x = math.cos(angle) * speed, y = math.sin(angle) * speed}
    self.friction = 0.95
    
    -- State
    self.isCollected = false
    self.pickupDelay = 0   -- seconds before it can be picked up (used for dropped items)

    return self
end

function Loot:update(dt)
    if self.isCollected then return end
    
    -- Count down the pickup delay
    if self.pickupDelay > 0 then
        self.pickupDelay = math.max(0, self.pickupDelay - dt)
    end

    -- Update lifetime
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.isCollected = true
        return
    end
    
    -- Update physics (top-down, so no gravity; damping is frame-rate independent)
    local damping = self.friction ^ (dt * 60)
    self.velocity.x = self.velocity.x * damping
    self.velocity.y = self.velocity.y * damping
    
    -- Update position
    self.x = self.x + self.velocity.x * dt
    self.y = self.y + self.velocity.y * dt
    
    -- Update rotation
    if self.item.effects.rotate then
        self.rotation = self.rotation + self.item.effects.rotateSpeed * dt
    end
end

-- Item definition for an item type (name, color, effect, ...)
function Loot.getItem(itemType)
    return config.items[itemType]
end

-- Apply an item's effect to the player. Returns true only if it did something,
-- so a full-health player keeps a health crystal instead of wasting it.
function Loot.applyItemEffect(itemType, player)
    local item = config.items[itemType]
    if not item then return false end

    if item.type == "consumable" then
        if item.effect == "heal" and player.health < player.maxHealth then
            player:heal(item.value)
            return true
        elseif item.effect == "energy" and player.energy < player.maxEnergy then
            player.energy = math.min(player.maxEnergy, player.energy + item.value)
            return true
        elseif item.effect == "shield" and player.shield < player.maxShield then
            player.shield = math.min(player.maxShield, player.shield + item.value)
            return true
        elseif item.effect == "repair" and (player.health < player.maxHealth or player.shield < player.maxShield) then
            player:heal(item.value)
            player.shield = player.maxShield
            return true
        end
    elseif item.type == "upgrade" then
        -- Weapon upgrades boost the weapon currently in hand
        return player:upgradeWeapon(player.currentWeapon, item.value)
    end

    -- Materials, and items that would have no effect right now
    return false
end

-- Called when the player touches the item. Useful items apply at once; anything
-- else goes to the inventory. If the inventory is full the item stays on the ground.
function Loot:applyEffect(player)
    if self.isCollected or self.pickupDelay > 0 then return false end

    if Loot.applyItemEffect(self.type, player) or player:addItem(self.type) then
        self.isCollected = true
        return true
    end
    return false
end

function Loot:draw()
    if self.isCollected then return end
    
    -- Calculate pulse scale
    local scale = 1
    if self.item.effects.pulse then
        scale = 1 + math.sin(love.timer.getTime() * self.item.effects.pulseSpeed) * self.item.effects.pulseScale
    end
    
    -- Draw glow effect
    if self.item.effects.glow then
        love.graphics.setColor(unpack(self.item.effects.glowColor))
        love.graphics.circle("fill", self.x, self.y, self.item.size * 1.5 * scale)
    end
    
    -- Draw item
    love.graphics.setColor(unpack(self.item.color))
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)
    love.graphics.circle("fill", 0, 0, self.item.size * scale)
    love.graphics.pop()
    
    -- Draw lifetime indicator
    local alpha = self.lifetime / self.item.lifetime
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("line", self.x, self.y, self.item.size * 1.2 * scale)
end

return Loot 