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

function UI.new()
    local self = setmetatable({}, UI)
    
    -- UI state
    self.showInventory = false
    self.showMap = false
    self.showMenu = false
    
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
    
    -- Draw health bar
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", config.padding, config.padding, config.healthBarWidth, config.healthBarHeight)
    
    -- Draw shield bar
    love.graphics.setColor(0, 0, 1)
    love.graphics.rectangle("fill", config.padding, config.padding + config.healthBarHeight + 5, config.healthBarWidth, config.healthBarHeight)
    
    -- Draw weapon info
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Weapon: Laser Pistol", config.padding, config.padding + config.healthBarHeight * 2 + 10)
    
    -- Restore color
    love.graphics.setColor(r, g, b, a)
end

function UI:drawInventory()
    -- Save current color
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw inventory background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw inventory grid
    love.graphics.setColor(1, 1, 1)
    for i = 1, 8 do
        local x = (i - 1) * (config.inventorySlotSize + 5) + config.padding
        local y = love.graphics.getHeight() - config.inventorySlotSize - config.padding
        love.graphics.rectangle("line", x, y, config.inventorySlotSize, config.inventorySlotSize)
    end
    
    -- Restore color
    love.graphics.setColor(r, g, b, a)
end

function UI:drawMap()
    -- TODO: Implement map drawing
    love.graphics.print("Map View", love.graphics.getWidth() / 2 - 50, love.graphics.getHeight() / 2)
end

function UI:drawMenu()
    -- Save current color
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw menu background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw menu options
    love.graphics.setColor(1, 1, 1)
    local centerX = love.graphics.getWidth() / 2
    local centerY = love.graphics.getHeight() / 2
    love.graphics.print("PAUSED", centerX - 50, centerY - 50, 0, 2)
    love.graphics.print("Resume", centerX - 50, centerY, 0, 1)
    love.graphics.print("Save Game", centerX - 50, centerY + 30, 0, 1)
    love.graphics.print("Load Game", centerX - 50, centerY + 60, 0, 1)
    love.graphics.print("Quit", centerX - 50, centerY + 90, 0, 1)
    
    -- Restore color
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