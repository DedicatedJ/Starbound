-- Star map screen: pick a destination and jump.
local Session = require("src.game.session")

local StarMap = {}
StarMap.__index = StarMap

local MARGIN = 80
local NODE_RADIUS = 14

function StarMap.new(session)
    local self = setmetatable({}, StarMap)
    self.session = session
    self.selected = 1
    self.message = nil
    -- Fixed background stars
    local rng = love.math.newRandomGenerator(4242)
    self.stars = {}
    for i = 1, 160 do
        self.stars[i] = {x = rng:random(), y = rng:random(), b = 0.3 + rng:random() * 0.7}
    end
    return self
end

-- Select the current location when the map opens
function StarMap:open()
    self.message = nil
    for i, loc in ipairs(Session.locations()) do
        if loc.id == self.session.location then
            self.selected = i
        end
    end
end

function StarMap:move(delta)
    local count = #Session.locations()
    self.selected = (self.selected - 1 + delta) % count + 1
    self.message = nil
end

function StarMap:selectedLocation()
    return Session.locations()[self.selected]
end

-- Screen position of a location node
function StarMap:nodePosition(loc)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local mapW, mapH = w - MARGIN * 2 - 320, h - MARGIN * 2
    return MARGIN + loc.x * mapW, MARGIN + loc.y * mapH
end

function StarMap:nodeAt(sx, sy)
    for i, loc in ipairs(Session.locations()) do
        local x, y = self:nodePosition(loc)
        if (sx - x) ^ 2 + (sy - y) ^ 2 <= (NODE_RADIUS + 6) ^ 2 then
            return i
        end
    end
    return nil
end

function StarMap:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local session = self.session

    love.graphics.setColor(0.02, 0.02, 0.06)
    love.graphics.rectangle("fill", 0, 0, w, h)
    for _, star in ipairs(self.stars) do
        love.graphics.setColor(1, 1, 1, star.b)
        love.graphics.points(star.x * w, star.y * h)
    end

    -- Jump range ring around the current location
    local current = session:currentLocation()
    local cx, cy = self:nodePosition(current)
    local mapW = w - MARGIN * 2 - 320
    love.graphics.setColor(0.3, 0.6, 1, 0.25)
    love.graphics.circle("line", cx, cy, session:jumpRange() * mapW)

    -- Routes from here: green if the jump is possible, dim red if not
    for _, loc in ipairs(Session.locations()) do
        if loc.id ~= current.id then
            local ok = session:canTravel(loc.id)
            local x, y = self:nodePosition(loc)
            if ok then
                love.graphics.setColor(0.3, 1, 0.4, 0.7)
            else
                love.graphics.setColor(1, 0.3, 0.3, 0.2)
            end
            love.graphics.line(cx, cy, x, y)
        end
    end

    -- Nodes
    for i, loc in ipairs(Session.locations()) do
        local x, y = self:nodePosition(loc)
        local color = (loc.kind == "station" and {0.6, 0.8, 1}) or (loc.kind == "rift" and {0.7, 0.3, 1}) or {0.9, 0.8, 0.5}
        love.graphics.setColor(color)
        if session.visited[loc.id] then
            love.graphics.circle("fill", x, y, NODE_RADIUS)
        else
            love.graphics.circle("line", x, y, NODE_RADIUS)
        end
        if session.fragments[loc.id] then
            love.graphics.setColor(1, 1, 0.3)
            love.graphics.circle("line", x, y, NODE_RADIUS + 5)
        end
        if i == self.selected then
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", x, y, NODE_RADIUS + 9)
        end
        if loc.id == current.id then
            love.graphics.setColor(0.3, 1, 0.4)
            love.graphics.print("YOU", x - 12, y - NODE_RADIUS - 32)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(loc.name, x - 70, y + NODE_RADIUS + 6, 140, "center")
    end

    -- Info panel
    local panelX = w - 320 - 20
    love.graphics.setColor(0.08, 0.08, 0.14, 0.95)
    love.graphics.rectangle("fill", panelX, MARGIN, 320, h - MARGIN * 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("STAR MAP", panelX, MARGIN + 12, 160, "center", 0, 2)
    local loc = self:selectedLocation()
    local ok, cost, reason = session:canTravel(loc.id)
    local lines = {
        loc.name,
        "",
        loc.description,
        "",
        ("Distance: %.2f   Jump range: %.2f"):format(Session.distance(current.id, loc.id), session:jumpRange()),
        ("Fuel: %d / %d"):format(session.fuel, session:maxFuel()),
        ("Star map fragments: %d / 3"):format(session:fragmentCount()),
        ""
    }
    if ok then
        table.insert(lines, cost > 0 and ("Press Enter to jump (uses %d fuel)"):format(cost) or ("Press Enter: " .. reason))
    else
        table.insert(lines, reason)
    end
    love.graphics.printf(table.concat(lines, "\n"), panelX + 16, MARGIN + 60, 288, "left")
    if self.message then
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(self.message, panelX + 16, h - MARGIN - 60, 288, "left")
    end

    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("Left/Right or click to choose, Enter to jump, Esc to close", 0, h - 30, w, "center")
end

return StarMap
