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
    if not sep then sep = "%s" end
    local t = {}
    for s in string.gmatch(str, "([^"..sep.."]+)") do
        table.insert(t, s)
    end
    return t
end

function Utils.trim(str)
    return str:match("^%s*(.-)%s*$")
end

-- Color utilities
function Utils.hexToRGB(hex)
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

function Utils.RGBToHex(r, g, b)
    return string.format("#%02X%02X%02X", r, g, b)
end

-- Random utilities
function Utils.randomFloat(min, max)
    return min + math.random() * (max - min)
end

function Utils.randomInt(min, max)
    return math.floor(Utils.randomFloat(min, max))
end

function Utils.randomChoice(t)
    return t[math.random(#t)]
end

-- Debug utilities
function Utils.debugPrint(...)
    if love.filesystem.getInfo("debug.log") then
        local file = io.open("debug.log", "a")
        if file then
            file:write(os.date("%Y-%m-%d %H:%M:%S ") .. table.concat({...}, " ") .. "\n")
            file:close()
        end
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
        return love.audio.newSource(path)
    end)
    if success then
        return sound
    else
        Utils.debugPrint("Failed to load sound: " .. path)
        return nil
    end
end

return Utils 