-- Buying upgrades: checks materials, takes payment, applies effects.
local UpgradeData = require("src.data.upgrades")
local Player = require("src.entities.player")
local Loot = require("src.entities.loot")

local Upgrades = {}

local byId = {}
for _, upgrade in ipairs(UpgradeData) do
    byId[upgrade.id] = upgrade
end

function Upgrades.list()
    return UpgradeData
end

function Upgrades.get(id)
    return byId[id]
end

-- Human-readable cost, e.g. "4 Salvage, 2 Alien Essence"
function Upgrades.costText(upgrade)
    local parts = {}
    local types = {}
    for itemType in pairs(upgrade.cost) do table.insert(types, itemType) end
    table.sort(types)
    for _, itemType in ipairs(types) do
        local item = Loot.getItem(itemType)
        table.insert(parts, ("%d %s"):format(upgrade.cost[itemType], item and item.name or itemType))
    end
    return table.concat(parts, ", ")
end

-- Returns ok, reason
function Upgrades.canBuy(session, player, id)
    local upgrade = byId[id]
    if not upgrade then
        return false, "Unknown upgrade"
    end
    if session:hasUpgrade(id) then
        return false, "Already installed"
    end
    for itemType, amount in pairs(upgrade.cost) do
        if player:countItem(itemType) < amount then
            local item = Loot.getItem(itemType)
            return false, ("Need %d %s (you have %d)"):format(amount, item and item.name or itemType, player:countItem(itemType))
        end
    end
    return true
end

-- Returns ok, reason
function Upgrades.buy(session, player, id)
    local ok, reason = Upgrades.canBuy(session, player, id)
    if not ok then
        return false, reason
    end
    for itemType, amount in pairs(byId[id].cost) do
        player:removeItemsOfType(itemType, amount)
    end
    session.upgrades[id] = true
    Upgrades.applyToPlayer(session, player)
    return true
end

-- Set player stats from base values plus installed gear (safe to call repeatedly)
function Upgrades.applyToPlayer(session, player)
    local stats = {}
    for key, value in pairs(Player.BASE) do stats[key] = value end
    for _, upgrade in ipairs(UpgradeData) do
        if upgrade.bonus and session:hasUpgrade(upgrade.id) then
            for key, amount in pairs(upgrade.bonus) do
                stats[key] = stats[key] + amount
            end
        end
    end
    -- Raising a maximum also tops the current value up by the same amount
    local gainHealth = stats.maxHealth - player.maxHealth
    local gainShield = stats.maxShield - player.maxShield
    local gainEnergy = stats.maxEnergy - player.maxEnergy
    player.maxHealth, player.maxShield, player.maxEnergy = stats.maxHealth, stats.maxShield, stats.maxEnergy
    player.energyRechargeRate = stats.energyRechargeRate
    player.health = math.min(player.maxHealth, player.health + math.max(0, gainHealth))
    player.shield = math.min(player.maxShield, player.shield + math.max(0, gainShield))
    player.energy = math.min(player.maxEnergy, player.energy + math.max(0, gainEnergy))
end

return Upgrades
