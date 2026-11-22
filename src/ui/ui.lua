local Loot = require("src.entities.loot")
local Utils = require("src.utils.utils")
local World = require("src.world.world")

local UI = {}
UI.__index = UI

-- UI configuration
local config = {
    padding = 10,
    fontSize = 16,
    inventorySlotSize = 40,
    healthBarWidth = 200,
    healthBarHeight = 20
}

function UI.new(player, world)
    local self = setmetatable({}, UI)

    -- Player whose stats the HUD shows, and the world the map shows
    self.player = player
    self.world = world
    self.session = nil   -- campaign session (location, fuel), set by the game
    self.prompt = nil    -- interaction prompt such as "[E] Open star map"
    
    -- UI state
    self.showInventory = false
    self.showMap = false
    self.showMenu = false

    -- Pause menu
    self.menuOptions = {"Resume", "Save Game", "Load Game", "Quit"}
    self.menuIndex = 1
    self.menuMessage = nil
    self.menuMessageTimer = 0

    -- UI elements
    self.elements = {}
    
    return self
end

function UI:addElement(element)
    table.insert(self.elements, element)
end

function UI:removeElement(element)
    for i, e in ipairs(self.elements) do
        if e == element then
            table.remove(self.elements, i)
            break
        end
    end
end

function UI:update(dt)
    if self.menuMessageTimer > 0 then
        self.menuMessageTimer = self.menuMessageTimer - dt
        if self.menuMessageTimer <= 0 then
            self.menuMessage = nil
        end
    end

    -- Update all UI elements
    for _, element in ipairs(self.elements) do
        if element.update then
            element:update(dt)
        end
    end
end

function UI:draw()
    -- Draw all UI elements
    for _, element in ipairs(self.elements) do
        if element.draw then
            element:draw()
        end
    end
    
    -- Draw HUD
    self:drawHUD()
    
    -- Draw inventory if open
    if self.showInventory then
        self:drawInventory()
    end
    
    -- Draw map if open
    if self.showMap then
        self:drawMap()
    end
    
    -- Draw menu if open
    if self.showMenu then
        self:drawMenu()
    end
end

function UI:drawHUD()
    -- Save current color
    local r, g, b, a = love.graphics.getColor()
    
    local p = self.player
    if p then
        local x, y = config.padding, config.padding
        local w, h = config.healthBarWidth, config.healthBarHeight
        local step = h + 5
        
        self:drawBar(x, y, w, h, p.health / p.maxHealth, {1, 0, 0})
        self:drawBar(x, y + step, w, h, p.shield / p.maxShield, {0, 0, 1})
        self:drawBar(x, y + step * 2, w, h, p.energy / p.maxEnergy, {0, 1, 1})
        
        -- Draw weapon info
        love.graphics.setColor(1, 1, 1)
        local level = p.weaponLevels and p.weaponLevels[p.currentWeapon] or 1
        local label = p.weapons[p.currentWeapon].name .. (level > 1 and (" +" .. (level - 1)) or "")
        love.graphics.print("Weapon: " .. label, x, y + step * 3 + 5)
    end

    -- Location and ship status, top right
    if self.session then
        local loc = self.session:currentLocation()
        local screenW = love.graphics.getWidth()
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(loc.name, screenW - 260, config.padding, 250, "right")
        love.graphics.printf(("Fuel %d/%d   Fragments %d/3"):format(self.session.fuel, self.session:maxFuel(), self.session:fragmentCount()),
            screenW - 260, config.padding + 18, 250, "right")
    end

    -- Interaction prompt, bottom center
    if self.prompt then
        local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", screenW / 2 - 180, screenH - 110, 360, 28)
        love.graphics.setColor(1, 1, 0.6)
        love.graphics.printf(self.prompt, screenW / 2 - 180, screenH - 103, 360, "center")
    end
    
    -- Restore color
    love.graphics.setColor(r, g, b, a)
end

function UI:drawBar(x, y, w, h, fraction, color)
    fraction = Utils.clamp(fraction, 0, 1)
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Fill
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, w * fraction, h)
    
    -- Outline
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, w, h)
end

-- Screen rectangle of an inventory slot (slots are centered along the bottom)
function UI:inventorySlotRect(index)
    local size, gap = config.inventorySlotSize, 8
    local count = self.player and self.player.inventorySize or 8
    local totalWidth = count * size + (count - 1) * gap
    local x = (love.graphics.getWidth() - totalWidth) / 2 + (index - 1) * (size + gap)
    local y = love.graphics.getHeight() - size - 60
    return x, y, size, size
end

-- Inventory slot index under a screen position, or nil
function UI:inventorySlotAt(sx, sy)
    if not (self.showInventory and self.player) then return nil end
    for i = 1, self.player.inventorySize do
        local x, y, w, h = self:inventorySlotRect(i)
        if sx >= x and sx <= x + w and sy >= y and sy <= y + h then
            return i
        end
    end
    return nil
end

function UI:drawInventory()
    local r, g, b, a = love.graphics.getColor()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- Dim the game behind the inventory
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("INVENTORY", 0, screenH - 140, screenW / 2, "center", 0, 2)
    love.graphics.printf("Click to use, right-click to drop, keys 6-8 use slots 1-3, I to close",
        0, screenH - 25, screenW, "center")

    local mx, my = love.mouse.getPosition()
    local hovered = self:inventorySlotAt(mx, my)
    for i = 1, (self.player and self.player.inventorySize or 8) do
        local x, y, w, h = self:inventorySlotRect(i)
        love.graphics.setColor(1, 1, 1, i == hovered and 0.25 or 0.1)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x, y, w, h)

        local stack = self.player and self.player.inventory[i]
        if stack then
            local item = Loot.getItem(stack.type)
            love.graphics.setColor(item.color)
            love.graphics.circle("fill", x + w / 2, y + h / 2, w * 0.3)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(tostring(stack.count), x + 3, y + h - 15)
            if i == hovered then
                love.graphics.printf(item.name, x - 40, y - 20, w + 80, "center")
            end
        end
    end

    love.graphics.setColor(r, g, b, a)
end

local MAP_CELL = 18   -- pixels per chunk on the map

function UI:drawMap()
    local r, g, b, a = love.graphics.getColor()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("MAP", 0, 20, screenW / 2, "center", 0, 2)
    love.graphics.printf("M to close", 0, screenH - 25, screenW, "center")

    local world, player = self.world, self.player
    if not (world and player) then
        love.graphics.setColor(r, g, b, a)
        return
    end

    -- Explored chunks, centered on the chunk the player is in
    local pcx, pcy = world.currentChunk.x, world.currentChunk.y
    local centerX, centerY = screenW / 2, screenH / 2
    for key in pairs(world.explored) do
        local chunk = world.chunks[key]
        if chunk then
            local x = centerX + (chunk.x - pcx) * MAP_CELL - MAP_CELL / 2
            local y = centerY + (chunk.y - pcy) * MAP_CELL - MAP_CELL / 2
            if x > -MAP_CELL and x < screenW and y > 60 and y < screenH - 60 then
                love.graphics.setColor(World.biomeColor(chunk.biome))
                love.graphics.rectangle("fill", x, y, MAP_CELL - 2, MAP_CELL - 2)
                if chunk.key == world.startChunkKey then
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.rectangle("line", x, y, MAP_CELL - 2, MAP_CELL - 2)
                end
            end
        end
    end

    -- Player marker at their exact position inside the current chunk
    local size = World.chunkPixels()
    local markerX = centerX + (player.x / size - pcx) * MAP_CELL - MAP_CELL / 2
    local markerY = centerY + (player.y / size - pcy) * MAP_CELL - MAP_CELL / 2
    love.graphics.setColor(0, 1, 0)
    love.graphics.circle("fill", markerX, markerY, 4)

    -- Legend
    local legendY = 70
    for _, biome in ipairs(world.biomeList) do
        love.graphics.setColor(World.biomeColor(biome))
        love.graphics.rectangle("fill", 20, legendY, 14, 14)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(biome:gsub("_", " "), 40, legendY)
        legendY = legendY + 20
    end
    love.graphics.print("White outline: landing site", 20, legendY + 6)

    love.graphics.setColor(r, g, b, a)
end

-- Screen rectangle of a pause menu option
function UI:menuOptionRect(index)
    local centerX, centerY = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    return centerX - 100, centerY - 10 + (index - 1) * 36, 200, 30
end

function UI:menuOptionAt(sx, sy)
    if not self.showMenu then return nil end
    for i = 1, #self.menuOptions do
        local x, y, w, h = self:menuOptionRect(i)
        if sx >= x and sx <= x + w and sy >= y and sy <= y + h then
            return i
        end
    end
    return nil
end

function UI:menuMove(delta)
    self.menuIndex = (self.menuIndex - 1 + delta) % #self.menuOptions + 1
end

function UI:menuSelected()
    return self.menuOptions[self.menuIndex]
end

-- Short status line under the menu ("Game saved", ...)
function UI:showMenuMessage(text)
    self.menuMessage = text
    self.menuMessageTimer = 3
end

function UI:drawMenu()
    local r, g, b, a = love.graphics.getColor()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", 0, screenH / 2 - 80, screenW / 2, "center", 0, 2)
    for i, option in ipairs(self.menuOptions) do
        local x, y, w, h = self:menuOptionRect(i)
        if i == self.menuIndex then
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.rectangle("fill", x, y, w, h)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(option, x, y + 8, w, "center")
    end
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("Up/Down or mouse to choose, Enter or click to select, Esc to resume",
        0, screenH - 25, screenW, "center")
    if self.menuMessage then
        love.graphics.setColor(1, 1, 0.4)
        local _, lastY = self:menuOptionRect(#self.menuOptions)
        love.graphics.printf(self.menuMessage, 0, lastY + 50, screenW, "center")
    end

    love.graphics.setColor(r, g, b, a)
end

function UI:toggleInventory()
    self.showInventory = not self.showInventory
end

function UI:toggleMap()
    self.showMap = not self.showMap
end

function UI:toggleMenu()
    self.showMenu = not self.showMenu
    self.menuIndex = 1
    self.menuMessage = nil
end

function UI:mousepressed(x, y, button)
    -- Handle mouse input for UI elements
    for _, element in ipairs(self.elements) do
        if element.mousepressed then
            element:mousepressed(x, y, button)
        end
    end
end

function UI:mousereleased(x, y, button)
    -- Handle mouse input for UI elements
    for _, element in ipairs(self.elements) do
        if element.mousereleased then
            element:mousereleased(x, y, button)
        end
    end
end

return UI 