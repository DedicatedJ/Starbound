-- Dialogue box: shows lines one at a time; the last line may offer numbered choices.
local Dialogue = {}
Dialogue.__index = Dialogue

function Dialogue.new()
    local self = setmetatable({}, Dialogue)
    self.active = false
    self.lines = {}
    self.index = 1
    self.choices = nil
    return self
end

-- options: onDone(choiceId), skippable (Esc ends it), flags (for choice requirements)
function Dialogue:start(lines, options)
    options = options or {}
    self.lines = lines
    self.index = 1
    self.onDone = options.onDone
    self.skippable = options.skippable ~= false
    self.flags = options.flags or {}
    self.active = true
    self:prepareChoices()
end

-- Choices visible on the current line, filtered by story flags
function Dialogue:prepareChoices()
    self.choices = nil
    local line = self.lines[self.index]
    if line and line.choices then
        self.choices = {}
        for _, choice in ipairs(line.choices) do
            if not choice.requires or self.flags[choice.requires] then
                table.insert(self.choices, choice)
            end
        end
    end
end

function Dialogue:currentLine()
    return self.lines[self.index]
end

-- Next line (ignored while a choice is waiting)
function Dialogue:advance()
    if not self.active or self.choices then return end
    self.index = self.index + 1
    if self.index > #self.lines then
        self:finish(nil)
    else
        self:prepareChoices()
    end
end

function Dialogue:choose(number)
    if not (self.active and self.choices and self.choices[number]) then return false end
    self:finish(self.choices[number].id)
    return true
end

-- Esc: end the dialogue early, but never skip a choice
function Dialogue:skip()
    if not self.active then return end
    if self.choices then return end
    if not self.skippable then return end
    -- Jump to a choice line if there is one ahead
    for i = self.index, #self.lines do
        if self.lines[i].choices then
            self.index = i
            self:prepareChoices()
            return
        end
    end
    self:finish(nil)
end

function Dialogue:finish(choiceId)
    self.active = false
    self.choices = nil
    local callback = self.onDone
    self.onDone = nil
    if callback then callback(choiceId) end
end

-- Screen rectangle of a choice row
function Dialogue:choiceRect(number)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local count = self.choices and #self.choices or 0
    return w / 2 - 330, h - 60 - (count - number + 1) * 30, 660, 26
end

function Dialogue:choiceAt(sx, sy)
    if not self.choices then return nil end
    for i = 1, #self.choices do
        local x, y, cw, ch = self:choiceRect(i)
        if sx >= x and sx <= x + cw and sy >= y and sy <= y + ch then
            return i
        end
    end
    return nil
end

function Dialogue:draw()
    if not self.active then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local line = self:currentLine()
    local choiceSpace = self.choices and (#self.choices * 30 + 10) or 0
    local boxH = 130 + choiceSpace
    local boxY = h - boxH - 20

    love.graphics.setColor(0.03, 0.04, 0.08, 0.92)
    love.graphics.rectangle("fill", w / 2 - 350, boxY, 700, boxH)
    love.graphics.setColor(0.5, 0.6, 1, 0.8)
    love.graphics.rectangle("line", w / 2 - 350, boxY, 700, boxH)

    local textY = boxY + 14
    if line.speaker then
        love.graphics.setColor(1, 0.85, 0.4)
        love.graphics.print(line.speaker, w / 2 - 330, textY)
        textY = textY + 22
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(line.text, w / 2 - 330, textY, 660, "left")

    if self.choices then
        local mx, my = love.mouse.getPosition()
        local hovered = self:choiceAt(mx, my)
        for i, choice in ipairs(self.choices) do
            local x, y, cw, ch = self:choiceRect(i)
            love.graphics.setColor(1, 1, 1, i == hovered and 0.2 or 0.08)
            love.graphics.rectangle("fill", x, y, cw, ch)
            love.graphics.setColor(0.6, 1, 0.7)
            love.graphics.print(("%d. %s"):format(i, choice.text), x + 8, y + 5)
        end
    end

    love.graphics.setColor(0.7, 0.7, 0.7)
    local hint = self.choices and "Press 1-" .. #self.choices .. " or click to choose"
        or ("Space or click to continue" .. (self.skippable and ", Esc to skip" or ""))
    love.graphics.printf(hint, w / 2 - 330, boxY + boxH - 24, 660, "right")
end

return Dialogue
