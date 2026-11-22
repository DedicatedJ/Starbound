-- Vaults: environmental puzzles that guard the star map fragments.
--
-- Three puzzle types:
--   sequence   - watch a sequence of colored pylons light up, then activate them in that order (E)
--   resonance  - shoot crystals; each hit toggles that crystal and its two neighbours; light them all
--   plates     - stand on numbered plates to toggle them; make the active plates add up to the door's number
--
-- A vault adds its parts to a world as interactables. Its state (solved, collected) is saved.
local Enemy = require("src.entities.enemy")

local Vault = {}
Vault.__index = Vault

local SEQUENCE_COLORS = {
    {1, 0.3, 0.3}, {0.3, 1, 0.4}, {0.3, 0.5, 1}, {1, 0.9, 0.3}
}
local SEQUENCE_LENGTH = 5
local FLASH_TIME = 0.6

local HINTS = {
    sequence = "The glyphs say: watch the pylons, then wake them in the same order.",
    resonance = "The glyphs say: strike the crystals until every one of them sings.",
    plates = "The glyphs say: the stones must weigh exactly what the door asks."
}

-- options: x, y, puzzle, seed, enemyType, notify(text), onCollect(vault)
function Vault.new(world, options)
    local self = setmetatable({}, Vault)
    self.world = world
    self.x, self.y = options.x, options.y
    self.puzzle = options.puzzle
    self.notify = options.notify or function() end
    self.onCollect = options.onCollect or function() end
    self.enemyType = options.enemyType or "ALIEN_WILDLIFE"
    self.rng = love.math.newRandomGenerator(options.seed or 1)
    self.solved = false
    self.collected = false
    self.parts = {}

    self:createDoor()
    if self.puzzle == "sequence" then
        self:createSequence()
    elseif self.puzzle == "resonance" then
        self:createResonance()
    elseif self.puzzle == "plates" then
        self:createPlates()
    end
    world.vault = self
    return self
end

function Vault:addPart(part)
    table.insert(self.parts, part)
    return self.world:addInteractable(part)
end

-- ------------------------------------------------------------------ door

function Vault:createDoor()
    local vault = self
    self.door = self:addPart({
        id = "vault_door", label = "Vault (sealed)", x = self.x, y = self.y, radius = 80,
        prompt = "[E] Read the glyphs",
        onInteract = function() vault:useDoor() end,
        draw = function(part) vault:drawDoor(part) end
    })
end

function Vault:useDoor()
    if self.collected then
        return
    elseif self.solved then
        self:collect()
        return
    end
    -- The first touch: the door checks for the Solis key, then shows its puzzle
    local prefix = ""
    if not self.keyRead then
        self.keyRead = true
        prefix = "The door reads your key and wakes.  "
    end
    if self.puzzle == "sequence" then
        self:startSequence()
        self.notify(prefix .. HINTS.sequence)
    elseif self.puzzle == "plates" then
        self.notify(prefix .. HINTS.plates .. ("  The door reads: %d."):format(self.target))
    else
        self.notify(prefix .. HINTS[self.puzzle])
    end
end

function Vault:setSolved()
    if self.solved then return end
    self.solved = true
    self.door.label = "Vault (open)"
    self.door.prompt = "[E] Take the star map fragment"
    self.notify("The vault door grinds open.")
end

function Vault:collect()
    self.collected = true
    self.door.label = "Vault (empty)"
    self.door.disabled = true
    self.onCollect(self)
end

function Vault:drawDoor(part)
    love.graphics.setColor(0.18, 0.16, 0.22)
    love.graphics.rectangle("fill", part.x - 45, part.y - 55, 90, 110)
    if self.solved and not self.collected then
        love.graphics.setColor(1, 0.95, 0.5, 0.6 + 0.4 * math.sin(love.timer.getTime() * 4))
        love.graphics.rectangle("fill", part.x - 25, part.y - 40, 50, 80)
    elseif self.solved then
        love.graphics.setColor(0.05, 0.05, 0.05)
        love.graphics.rectangle("fill", part.x - 25, part.y - 40, 50, 80)
    else
        love.graphics.setColor(0.6, 0.5, 0.9)
        love.graphics.rectangle("line", part.x - 25, part.y - 40, 50, 80)
        love.graphics.circle("line", part.x, part.y, 12)
        if self.puzzle == "plates" then
            love.graphics.printf(tostring(self.target), part.x - 25, part.y - 34, 50, "center")
        end
    end
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(part.label, part.x - 80, part.y - 78, 160, "center")
end

-- ------------------------------------------------------------- sequence

function Vault:createSequence()
    local vault = self
    self.sequence = {}
    for i = 1, SEQUENCE_LENGTH do
        self.sequence[i] = self.rng:random(1, #SEQUENCE_COLORS)
    end
    self.progress = 0          -- pylons activated correctly so far
    self.flashQueue = nil      -- remaining flashes while the sequence plays
    self.flashTimer = 0
    self.flashing = nil        -- pylon index currently lit by the playback
    self.pylons = {}
    local offsets = {{-150, -150}, {150, -150}, {150, 150}, {-150, 150}}
    for i, offset in ipairs(offsets) do
        self.pylons[i] = self:addPart({
            id = "pylon_" .. i, label = nil, index = i,
            x = self.x + offset[1], y = self.y + offset[2], radius = 55,
            prompt = "[E] Wake the pylon",
            onInteract = function(part) vault:activatePylon(part.index) end,
            update = i == 1 and function(_, dt) vault:updateSequence(dt) end or nil,
            draw = function(part) vault:drawPylon(part) end
        })
    end
end

function Vault:startSequence()
    if self.solved then return end
    self.progress = 0
    self.flashQueue = {}
    for i, v in ipairs(self.sequence) do self.flashQueue[i] = v end
    self.flashTimer = 0
    self.flashing = nil
end

function Vault:updateSequence(dt)
    if not self.flashQueue then return end
    self.flashTimer = self.flashTimer - dt
    if self.flashTimer <= 0 then
        if self.flashing then
            -- Gap between flashes
            self.flashing = nil
            self.flashTimer = FLASH_TIME * 0.4
        elseif #self.flashQueue > 0 then
            self.flashing = table.remove(self.flashQueue, 1)
            self.flashTimer = FLASH_TIME
        else
            self.flashQueue = nil
        end
    end
end

function Vault:activatePylon(index)
    if self.solved or self.flashQueue then return end
    if self.sequence[self.progress + 1] == index then
        self.progress = self.progress + 1
        if self.progress == #self.sequence then
            self:setSolved()
        end
    else
        -- Wrong pylon: the sequence resets and guardians appear
        self.progress = 0
        self.notify("Wrong order. The pylons go dark and something stirs.")
        self:spawnGuardians(2)
    end
end

function Vault:drawPylon(part)
    local color = SEQUENCE_COLORS[part.index]
    local lit = self.solved or self.flashing == part.index
        or (self.progress > 0 and self.sequence[self.progress] == part.index and not self.flashQueue)
    love.graphics.setColor(color[1] * 0.35, color[2] * 0.35, color[3] * 0.35)
    love.graphics.rectangle("fill", part.x - 14, part.y - 30, 28, 60)
    love.graphics.setColor(color[1], color[2], color[3], lit and 1 or 0.35)
    love.graphics.circle("fill", part.x, part.y - 30, lit and 16 or 11)
end

-- ------------------------------------------------------------- resonance

function Vault:createResonance()
    local vault = self
    self.crystals = {}
    local count = 5
    for i = 1, count do
        local angle = (i - 1) / count * math.pi * 2 - math.pi / 2
        self.crystals[i] = self:addPart({
            id = "crystal_" .. i, index = i, lit = true,
            x = self.x + math.cos(angle) * 170, y = self.y + math.sin(angle) * 170,
            radius = 0,                      -- not used with E
            hitRadius = 26,
            onHit = function(part) vault:strikeCrystal(part.index) end,
            draw = function(part) vault:drawCrystal(part) end
        })
    end
    -- Scramble from the solved state with real moves, so it is always solvable
    local moves = 0
    while moves < 3 do
        local i = self.rng:random(1, count)
        self:toggleCrystals(i)
        moves = moves + 1
    end
    if self:allCrystalsLit() then
        self:toggleCrystals(1)
    end
end

function Vault:toggleCrystals(index)
    local count = #self.crystals
    for _, offset in ipairs({-1, 0, 1}) do
        local c = self.crystals[(index - 1 + offset) % count + 1]
        c.lit = not c.lit
    end
end

function Vault:allCrystalsLit()
    for _, c in ipairs(self.crystals) do
        if not c.lit then return false end
    end
    return true
end

function Vault:strikeCrystal(index)
    if self.solved then return end
    self:toggleCrystals(index)
    if self:allCrystalsLit() then
        self:setSolved()
    end
end

function Vault:drawCrystal(part)
    local s = 22
    if part.lit then
        love.graphics.setColor(0.6, 0.95, 1)
    else
        love.graphics.setColor(0.2, 0.3, 0.4)
    end
    love.graphics.polygon("fill", part.x, part.y - s, part.x + s * 0.6, part.y, part.x, part.y + s, part.x - s * 0.6, part.y)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.polygon("line", part.x, part.y - s, part.x + s * 0.6, part.y, part.x, part.y + s, part.x - s * 0.6, part.y)
end

-- ---------------------------------------------------------------- plates

function Vault:createPlates()
    local vault = self
    self.plates = {}
    local count = 5
    for i = 1, count do
        self.plates[i] = self:addPart({
            id = "plate_" .. i, index = i, value = self.rng:random(1, 9), active = false, occupied = false,
            x = self.x + (i - 3) * 90, y = self.y + 160, radius = 0,
            update = function(part) vault:updatePlate(part) end,
            draw = function(part) vault:drawPlate(part) end
        })
    end
    -- The target is the sum of a random 2 or 3 plates, so a solution always exists
    local picks, target = {}, 0
    local size = self.rng:random(2, 3)
    while #picks < size do
        local i = self.rng:random(1, count)
        local taken = false
        for _, v in ipairs(picks) do if v == i then taken = true end end
        if not taken then
            table.insert(picks, i)
            target = target + self.plates[i].value
        end
    end
    self.target = target
end

function Vault:plateSum()
    local sum = 0
    for _, plate in ipairs(self.plates) do
        if plate.active then sum = sum + plate.value end
    end
    return sum
end

function Vault:updatePlate(part)
    if self.solved then return end
    local player = self.world:findPlayer()
    if not player then return end
    local inside = math.abs(player.x - part.x) <= 26 and math.abs(player.y - part.y) <= 26
    if inside and not part.occupied then
        -- Stepping onto a plate toggles it
        part.active = not part.active
        if self:plateSum() == self.target then
            self:setSolved()
        end
    end
    part.occupied = inside
end

function Vault:drawPlate(part)
    if part.active or self.solved then
        love.graphics.setColor(0.35, 0.8, 0.4)
    else
        love.graphics.setColor(0.35, 0.33, 0.3)
    end
    love.graphics.rectangle("fill", part.x - 26, part.y - 26, 52, 52)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", part.x - 26, part.y - 26, 52, 52)
    love.graphics.printf(tostring(part.value), part.x - 26, part.y - 7, 52, "center")
end

-- -------------------------------------------------------------- shared

function Vault:spawnGuardians(count)
    for i = 1, count do
        local angle = self.rng:random() * math.pi * 2
        local enemy = Enemy.new(self.x + math.cos(angle) * 260, self.y + math.sin(angle) * 260, self.enemyType,
            self.world:levelForChunk(0, 0))
        table.insert(self.world.enemies, enemy)
    end
end

function Vault:saveState()
    return {solved = self.solved, collected = self.collected}
end

function Vault:loadState(state)
    if not state then return end
    if state.solved then
        self:setSolvedQuietly()
    end
    if state.collected then
        self.collected = true
        self.door.label = "Vault (empty)"
        self.door.disabled = true
    end
end

function Vault:setSolvedQuietly()
    local notify = self.notify
    self.notify = function() end
    self:setSolved()
    self.notify = notify
end

return Vault
