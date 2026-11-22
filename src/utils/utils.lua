local Utils = {}

-- Math utilities
function Utils.lerp(a, b, t)
    return a + t * (b - a)
end

function Utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function Utils.distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function Utils.angle(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end

-- Table utilities
function Utils.copyTable(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = Utils.copyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function Utils.mergeTables(t1, t2)
    local result = Utils.copyTable(t1)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = Utils.mergeTables(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

-- String utilities
function Utils.split(str, sep)
    -- sep is a set of literal separator characters; escape the ones that are special in a character class
    local class = sep and sep:gsub("[%]%^%-%%]", "%%%0") or "%s"
    local t = {}
    for s in string.gmatch(str, "([^" .. class .. "]+)") do
        table.insert(t, s)
    end
    return t
end

function Utils.trim(str)
    return str:match("^%s*(.-)%s*$")
end

-- Color utilities (components are 0-1, as LÖVE 11 expects)
function Utils.hexToRGB(hex)
    hex = hex:gsub("#", "")
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

function Utils.RGBToHex(r, g, b)
    local function byte(c) return math.floor(Utils.clamp(c, 0, 1) * 255 + 0.5) end
    return string.format("#%02X%02X%02X", byte(r), byte(g), byte(b))
end

-- Random utilities
function Utils.randomFloat(min, max)
    return min + math.random() * (max - min)
end

-- Integer in [min, max], both ends included
function Utils.randomInt(min, max)
    return love.math.random(min, max)
end

function Utils.randomChoice(t)
    return t[math.random(#t)]
end

-- Debug utilities: appends to debug.log in the save directory, only if that file exists (opt-in)
function Utils.debugPrint(...)
    if love.filesystem.getInfo("debug.log") then
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        love.filesystem.append("debug.log", os.date("%Y-%m-%d %H:%M:%S ") .. table.concat(parts, " ") .. "\n")
    end
end

-- Time utilities
function Utils.formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, remainingSeconds)
end

-- Input utilities
function Utils.isKeyPressed(key)
    return love.keyboard.isDown(key)
end

function Utils.isMousePressed(button)
    return love.mouse.isDown(button)
end

function Utils.getMousePosition()
    return love.mouse.getX(), love.mouse.getY()
end

-- Asset utilities
function Utils.loadImage(path)
    local success, image = pcall(function()
        return love.graphics.newImage(path)
    end)
    if success then
        return image
    else
        Utils.debugPrint("Failed to load image: " .. path)
        return nil
    end
end

function Utils.loadSound(path)
    local success, sound = pcall(function()
        return love.audio.newSource(path, "static")
    end)
    if success then
        return sound
    else
        Utils.debugPrint("Failed to load sound: " .. path)
        return nil
    end
end

return Utils 