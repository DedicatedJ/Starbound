-- Upgrade terminal screen at Drift Station.
local Upgrades = require("src.game.upgrades")

local Shop = {}
Shop.__index = Shop

local ROW_HEIGHT = 56

function Shop.new(session, player)
    local self = setmetatable({}, Shop)
    self.session = session
    self.player = player
    self.selected = 1
    self.message = nil
    return self
end

function Shop:move(delta)
    local count = #Upgrades.list()
    self.selected = (self.selected - 1 + delta) % count + 1
    self.message = nil
end

function Shop:selectedUpgrade()
    return Upgrades.list()[self.selected]
end

function Shop:buySelected()
    local ok, reason = Upgrades.buy(self.session, self.player, self:selectedUpgrade().id)
    self.message = ok and ("Installed " .. self:selectedUpgrade().name) or reason
    return ok
end

function Shop:rowRect(index)
    local w = love.graphics.getWidth()
    return w / 2 - 340, 110 + (index - 1) * ROW_HEIGHT, 680, ROW_HEIGHT - 6
end

function Shop:rowAt(sx, sy)
    for i = 1, #Upgrades.list() do
        local x, y, rw, rh = self:rowRect(i)
        if sx >= x and sx <= x + rw and sy >= y and sy <= y + rh then
            return i
        end
    end
    return nil
end

function Shop:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0.04, 0.06, 0.08, 0.95)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(0.3, 1, 0.6)
    love.graphics.printf("DRIFT STATION UPGRADES", 0, 30, w / 2, "center", 0, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(("You carry: %d Salvage, %d Alien Essence"):format(self.player:countItem("salvage"), self.player:countItem("alien_essence")),
        0, 75, w, "center")

    for i, upgrade in ipairs(Upgrades.list()) do
        local x, y, rw, rh = self:rowRect(i)
        local owned = self.session:hasUpgrade(upgrade.id)
        local affordable = Upgrades.canBuy(self.session, self.player, upgrade.id)
        love.graphics.setColor(1, 1, 1, i == self.selected and 0.18 or 0.06)
        love.graphics.rectangle("fill", x, y, rw, rh)
        if owned then
            love.graphics.setColor(0.5, 1, 0.5)
        elseif affordable then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
        end
        love.graphics.print(("%s  [%s]"):format(upgrade.name, upgrade.kind == "ship" and "Ship" or "Gear"), x + 12, y + 6)
        love.graphics.print(upgrade.description, x + 12, y + 26)
        love.graphics.printf(owned and "Installed" or Upgrades.costText(upgrade), x, y + 6, rw - 12, "right")
    end

    if self.message then
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.printf(self.message, 0, h - 70, w, "center")
    end
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("Up/Down or click to choose, Enter or click again to buy, Esc to close", 0, h - 30, w, "center")
end

return Shop
