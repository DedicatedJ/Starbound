-- Save games: plain Lua table literals in the LÖVE save directory.
--
-- Saves are written by our own serializer and read back in a sandbox with no
-- globals and an instruction limit, so a tampered file cannot call game or OS
-- functions or hang the game.
local Save = {}

Save.VERSION = 1
Save.FILE = "save1.lua"

local MAX_INSTRUCTIONS = 1000000

local function serializeValue(value, indent, out)
    local kind = type(value)
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("cannot save non-finite number")
        end
        table.insert(out, string.format("%.17g", value))
    elseif kind == "string" then
        table.insert(out, string.format("%q", value))
    elseif kind == "boolean" then
        table.insert(out, tostring(value))
    elseif kind == "table" then
        -- Sort keys so the same data always produces the same file
        local keys = {}
        for k in pairs(value) do
            local keyType = type(k)
            if keyType ~= "string" and keyType ~= "number" then
                error("cannot save table key of type " .. keyType)
            end
            table.insert(keys, k)
        end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) == "number"
        end)
        local inner = indent .. "  "
        table.insert(out, "{\n")
        for _, k in ipairs(keys) do
            table.insert(out, inner .. "[")
            serializeValue(k, inner, out)
            table.insert(out, "] = ")
            serializeValue(value[k], inner, out)
            table.insert(out, ",\n")
        end
        table.insert(out, indent .. "}")
    else
        error("cannot save value of type " .. kind)
    end
end

function Save.serialize(data)
    local out = {"return "}
    serializeValue(data, "", out)
    table.insert(out, "\n")
    return table.concat(out)
end

-- Returns the table, or nil and an error message
function Save.deserialize(text)
    if type(text) ~= "string" then
        return nil, "no save data"
    end
    local chunk, err = loadstring(text, "=save")
    if not chunk then
        return nil, err
    end
    setfenv(chunk, {})
    if jit then jit.off(chunk, true) end   -- count hooks need interpreted code
    debug.sethook(function() error("save file is not a plain table") end, "", MAX_INSTRUCTIONS)
    local ok, result = pcall(chunk)
    debug.sethook()
    if not ok then
        return nil, tostring(result)
    end
    if type(result) ~= "table" then
        return nil, "save file is not a table"
    end
    return result
end

function Save.exists(file)
    return love.filesystem.getInfo(file or Save.FILE) ~= nil
end

function Save.write(data, file)
    local ok, err = love.filesystem.write(file or Save.FILE, Save.serialize(data))
    return ok, err
end

-- Returns the saved table, or nil and an error message
function Save.read(file)
    file = file or Save.FILE
    if not Save.exists(file) then
        return nil, "no save found"
    end
    local data, err = Save.deserialize(love.filesystem.read(file))
    if not data then
        return nil, err
    end
    if data.version ~= Save.VERSION then
        return nil, "save is from an incompatible version"
    end
    return data
end

function Save.delete(file)
    return love.filesystem.remove(file or Save.FILE)
end

return Save
