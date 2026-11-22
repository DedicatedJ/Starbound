-- Campaign state that outlives any single location: where the ship is, fuel,
-- upgrades, story flags and star map fragments.
local Galaxy = require("src.data.galaxy")

local Session = {}
Session.__index = Session

Session.BASE_JUMP_RANGE = 0.30
Session.BASE_MAX_FUEL = 3
Session.FUEL_PER_JUMP = 1

local locationsById = {}
for index, loc in ipairs(Galaxy.locations) do
    loc.index = index
    locationsById[loc.id] = loc
end

function Session.new(seed)
    local self = setmetatable({}, Session)
    self.seed = seed or love.math.random(1, 2147483646)
    self.location = Galaxy.start
    self.fuel = Session.BASE_MAX_FUEL
    self.upgrades = {}      -- upgrade id -> true
    self.flags = {}         -- story flags
    self.fragments = {}     -- location id -> true for each star map fragment recovered
    self.visited = {[Galaxy.start] = true}
    return self
end

function Session.locations()
    return Galaxy.locations
end

function Session.locationData(id)
    return locationsById[id]
end

function Session:currentLocation()
    return locationsById[self.location]
end

-- Seed for a location's world, derived from the campaign seed
function Session:locationSeed(id)
    local index = locationsById[id].index
    return (self.seed + index * 7919) % 2147483646 + 1
end

function Session:hasUpgrade(id)
    return self.upgrades[id] == true
end

function Session:jumpRange()
    return Session.BASE_JUMP_RANGE + (self:hasUpgrade("jump_drive") and 0.15 or 0)
end

function Session:maxFuel()
    return Session.BASE_MAX_FUEL + (self:hasUpgrade("fuel_tanks") and 3 or 0)
end

function Session:fragmentCount()
    local count = 0
    for _ in pairs(self.fragments) do count = count + 1 end
    return count
end

function Session.distance(idA, idB)
    local a, b = locationsById[idA], locationsById[idB]
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- Whether the ship can jump to a location now; returns ok, fuel cost, reason
function Session:canTravel(id)
    local target = locationsById[id]
    if not target then
        return false, 0, "Unknown location"
    end
    if id == self.location then
        return false, 0, "You are here"
    end

    local requires = target.requires
    if requires then
        if requires.fragments and self:fragmentCount() < requires.fragments then
            return false, 0, ("Coordinates incomplete: %d of %d star map fragments"):format(self:fragmentCount(), requires.fragments)
        end
        if requires.upgrade and not self:hasUpgrade(requires.upgrade) then
            return false, 0, "The Rift would tear the hull apart without Void Shielding"
        end
    end

    -- Out of fuel: a distress tow can always bring the ship home for free
    if self.fuel < Session.FUEL_PER_JUMP then
        if id == Galaxy.home then
            return true, 0, "Out of fuel: distress tow to " .. target.name
        end
        return false, 0, "Not enough fuel (Drift Station can tow you home)"
    end

    if Session.distance(self.location, id) > self:jumpRange() + 1e-9 then
        return false, 0, "Out of jump range (upgrade the jump drive)"
    end
    return true, Session.FUEL_PER_JUMP, nil
end

-- Jump to a location; returns ok, reason
function Session:travel(id)
    local ok, cost, reason = self:canTravel(id)
    if not ok then
        return false, reason
    end
    self.fuel = self.fuel - cost
    self.location = id
    self.visited[id] = true
    if locationsById[id].kind == "station" then
        self:refuel()
    end
    return true
end

function Session:refuel()
    self.fuel = self:maxFuel()
end

-- Plain data for save files
function Session:serialize()
    local function list(set)
        local out = {}
        for key, value in pairs(set) do
            if value then table.insert(out, key) end
        end
        table.sort(out)
        return out
    end
    local flags = {}
    for key, value in pairs(self.flags) do flags[key] = value end
    return {
        seed = self.seed,
        location = self.location,
        fuel = self.fuel,
        upgrades = list(self.upgrades),
        fragments = list(self.fragments),
        visited = list(self.visited),
        flags = flags
    }
end

function Session.fromSave(data)
    local self = Session.new(data.seed)
    self.location = locationsById[data.location] and data.location or Galaxy.start
    self.fuel = data.fuel or self.fuel
    local function set(list)
        local out = {}
        for _, key in ipairs(list or {}) do out[key] = true end
        return out
    end
    self.upgrades = set(data.upgrades)
    self.fragments = set(data.fragments)
    self.visited = set(data.visited)
    self.visited[self.location] = true
    for key, value in pairs(data.flags or {}) do self.flags[key] = value end
    return self
end

return Session
