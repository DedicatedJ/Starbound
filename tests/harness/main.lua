-- Test harness for Starbound Legacy.
--
-- Loads the real game (main.lua and src/), stubs keyboard and mouse input,
-- runs unit checks on the game modules, then plays through the tutorial,
-- death and restart. Prints PASS/FAIL lines and exits 0 when everything passes.
--
-- Usage, from the repository root:
--   Windows:  & "C:\Program Files\LOVE\lovec.exe" tests\harness
--   Linux:    love tests/harness
--   macOS:    /Applications/love.app/Contents/MacOS/love tests/harness
--
-- Optional arguments: <repo dir> <results file>
--   <repo dir>      game to test (default: two levels above this folder)
--   <results file>  also write the results to this file
local REPO, OUT
local results, failures = {}, 0

local function log(line) table.insert(results, line) end
local function check(name, ok, detail)
    if ok then log("PASS " .. name) else failures = failures + 1; log("FAIL " .. name .. (detail and (" :: " .. tostring(detail)) or "")) end
end
local function flush()
    local text = table.concat(results, "\n") .. "\n" .. (failures == 0 and "ALL PASSED" or ("FAILURES: " .. failures)) .. "\n"
    io.write(text)
    io.flush()
    if OUT then
        local f = assert(io.open(OUT, "w"))
        f:write(text)
        f:close()
    end
end

local function upvalue(fn, name)
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if n == name then return v end
        i = i + 1
    end
end

local bit = require("bit")

-- Input stubs
local keysDown, mouseX, mouseY = {}, 0, 0
love.keyboard.isDown = function(...)
    for _, k in ipairs({...}) do if keysDown[k] then return true end end
    return false
end
love.mouse.getPosition = function() return mouseX, mouseY end

local game = {}
local sim = { t = 0, frame = 0, phase = "unit" }
local DT = 1 / 60

local function state() return upvalue(game.update, "currentState") end
local function getPlayer() return upvalue(updateGame, "player") end
local function getWorld() return upvalue(updateGame, "world") end
local function getSession() return upvalue(travelToSelected, "session") end
local function getStarMap() return upvalue(openStarMap, "starMap") end

local function runUnitTests()
    local Player = require("src.entities.player")
    local Enemy = require("src.entities.enemy")
    local Loot = require("src.entities.loot")
    local World = require("src.world.world")

    -- Shield overflow
    local p = Player.new(100, 100)
    p:takeDamage(150)
    check("shield overflow carries to health", p.shield == 0 and p.health == 50, ("shield=%s health=%s"):format(p.shield, p.health))
    p:takeDamage(30)
    check("damage with no shield hits health", p.health == 20, p.health)

    -- Diagonal normalization and stop
    p = Player.new(400, 300)
    p:move(1, 1)
    local speed = math.sqrt(p.velocity.x ^ 2 + p.velocity.y ^ 2)
    check("diagonal speed equals straight speed", math.abs(speed - 200) < 0.001, speed)
    p:move(0, 0)
    check("move(0,0) stops the player", p.velocity.x == 0 and p.velocity.y == 0)

    -- Ion cannon charge fires automatically
    p = Player.new(400, 300)
    p:switchWeapon("ion_cannon")
    p.aimX, p.aimY = 600, 300
    local fired = p:fire(600, 300)
    check("ion cannon click starts charge, no shot yet", fired == false and p.isCharging and #p.projectiles == 0)
    for _ = 1, 40 do p:update(DT) end
    check("ion cannon fires when charge completes", #p.projectiles == 1, #p.projectiles)
    check("ion cannon spent energy", p.energy < 100, p.energy)

    -- Switching weapon mid-charge must not crash
    p = Player.new(400, 300)
    p:switchWeapon("ion_cannon")
    p:fire(600, 300)
    p:switchWeapon("laser_pistol")
    local ok, err = pcall(function() for _ = 1, 60 do p:update(DT) end end)
    check("switch weapon mid-charge does not crash", ok and not p.isCharging, err)

    -- Projectile range is per projectile
    p = Player.new(400, 300)
    p:switchWeapon("void_beam")
    p:fire(1000, 300)
    p:switchWeapon("scatter_shot")
    for _ = 1, 30 do p:update(DT) end -- 0.5s at 600px/s = 300px, beyond scatter range 250, within void range 600
    check("in-flight projectile keeps its own range", #p.projectiles == 1, #p.projectiles)

    -- Void Beam pierces and hits several enemies
    local w = World.new({spawnEnemies = false, tutorial = false})
    p = Player.new(100, 300)
    w:addEntity(p)
    local line = {}
    for i = 1, 3 do
        local e = Enemy.new(200 + i * 60, 300, "SPACE_PIRATE")
        e.health, e.maxHealth = 1000, 1000
        e.attackRange = 0
        table.insert(w.enemies, e); table.insert(line, e)
    end
    p:switchWeapon("void_beam")
    p:fire(1000, 300)
    for _ = 1, 40 do w:update(DT) end
    local hits = 0
    for _, e in ipairs(line) do if e.health < 1000 then hits = hits + 1 end end
    check("void beam pierces through 3 enemies", hits == 3, hits)

    -- Scatter shot: all 5 pellets overlapping an enemy hit in a single combat check
    w = World.new({spawnEnemies = false, tutorial = false})
    p = Player.new(100, 300)
    w:addEntity(p)
    local target = Enemy.new(100, 300, "SPACE_PIRATE") -- on top of the muzzle
    target.health, target.maxHealth = 1000, 1000
    table.insert(w.enemies, target)
    p:switchWeapon("scatter_shot")
    p:fire(1000, 300)
    w:checkCombat()
    check("all scatter pellets hit in one frame", 1000 - target.health == 5 * 8, 1000 - target.health)

    -- Enemy attacks damage the player
    w = World.new({spawnEnemies = false, tutorial = false})
    p = Player.new(400, 300)
    w:addEntity(p)
    table.insert(w.enemies, Enemy.new(450, 300, "ALIEN_WILDLIFE"))
    for _ = 1, 120 do w:update(DT) end
    check("enemies damage the player", p.shield < 100, p.shield)

    -- Loot stays near where it dropped
    local loot = Loot.new(300, 300, "health_crystal")
    for _ = 1, 300 do loot:update(DT) end
    local drift = math.sqrt((loot.x - 300) ^ 2 + (loot.y - 300) ^ 2)
    check("loot settles near drop point", drift < 40, drift)

    -- Shield crystal pickup uses maxShield
    p = Player.new(0, 0)
    p.shield = 50
    Loot.new(0, 0, "shield_crystal"):applyEffect(p)
    check("shield crystal restores shield", p.shield == 75, p.shield)

    -- Seeded generation: same seed and chunk give the same result, a different seed differs
    local function chunkSignature(chunk)
        local parts = {chunk.biome}
        for y = 1, #chunk.tiles do
            for x = 1, #chunk.tiles[y] do table.insert(parts, chunk.tiles[y][x].type:sub(1, 1)) end
        end
        for _, sp in ipairs(chunk.enemySpawns) do table.insert(parts, ("%s@%d,%d"):format(sp.enemyType, sp.x, sp.y)) end
        return table.concat(parts, "|")
    end
    local sigA = chunkSignature(World.new({seed = 12345}):generateChunk(3, -2))
    local sigB = chunkSignature(World.new({seed = 12345}):generateChunk(3, -2))
    local sigC = chunkSignature(World.new({seed = 777}):generateChunk(3, -2))
    check("same seed generates the same chunk", sigA == sigB)
    check("different seed generates a different chunk", sigA ~= sigC)
    local spawnChunk = World.new({seed = 12345}):generateChunk(3, -2)
    local px = World.chunkPixels()
    local inside = true
    for _, sp in ipairs(spawnChunk.enemySpawns) do
        if sp.x < 3 * px or sp.x >= 4 * px or sp.y < -2 * px or sp.y >= -1 * px then inside = false end
    end
    check("enemy spawns lie inside their chunk", inside)

    -- Chunk streaming. Pick the first seed whose 3x3 block around chunk (10,10) has spawns.
    local function expectedSpawns(seed, ccx, ccy, exceptKey)
        local probe, total = World.new({seed = seed, tutorial = false}), 0
        for cy = ccy - 1, ccy + 1 do
            for cx = ccx - 1, ccx + 1 do
                if World.chunkKey(cx, cy) ~= exceptKey then
                    total = total + #probe:generateChunk(cx, cy).enemySpawns
                end
            end
        end
        return total
    end
    local seed = 1
    while expectedSpawns(seed, 10, 10, nil) == 0 do seed = seed + 1 end

    w = World.new({seed = seed, tutorial = false})
    p = Player.new(0, 0)                         -- start chunk (0,0) is the safe chunk
    w:addEntity(p)
    w:update(DT)
    check("start chunk and its neighbours follow spawn data", #w.enemies == expectedSpawns(seed, 0, 0, "0,0"),
        ("%d vs %d"):format(#w.enemies, expectedSpawns(seed, 0, 0, "0,0")))
    for _, e in ipairs(w.enemies) do check("no enemy spawns in the start chunk", e.chunkKey ~= "0,0"); break end

    local px2 = World.chunkPixels()
    p.x, p.y = 10.5 * px2, 10.5 * px2           -- jump far away
    w:update(DT)
    local near, farLeft = 0, 0
    for _, e in ipairs(w.enemies) do
        local ecx, ecy = World.worldToChunk(e.spawnX, e.spawnY)
        if math.abs(ecx - 10) <= 1 and math.abs(ecy - 10) <= 1 then near = near + 1 else farLeft = farLeft + 1 end
    end
    check("far chunks despawn their enemies", farLeft == 0, farLeft)
    check("chunks around the player spawn their enemies", near == expectedSpawns(seed, 10, 10, nil) and near > 0, near)

    -- Defeat everything nearby, leave, come back: cleared chunks stay empty
    for _, e in ipairs(w.enemies) do e.isDead = true end
    w:update(DT)
    p.x, p.y = 0, 0
    w:update(DT)
    p.x, p.y = 10.5 * px2, 10.5 * px2
    w:update(DT)
    check("cleared chunks do not respawn", #w.enemies == 0, #w.enemies)
    check("visited chunks are marked explored", w.explored["10,10"] == true and w.explored["0,0"] == true)

    -- No chunk spawns while the tutorial is running
    w = World.new({seed = seed})
    p = Player.new(10.5 * px2, 10.5 * px2)
    w:addEntity(p)
    w:update(DT)
    check("no chunk enemies during the tutorial", #w.enemies == 0, #w.enemies)

    -- Enemy levels scale health and damage
    local e1, e3 = Enemy.new(0, 0, "ALIEN_WILDLIFE", 1), Enemy.new(0, 0, "ALIEN_WILDLIFE", 3)
    check("higher level enemies are tougher", e3.maxHealth > e1.maxHealth and e3.damage > e1.damage,
        ("hp %s/%s dmg %s/%s"):format(e1.maxHealth, e3.maxHealth, e1.damage, e3.damage))
    w = World.new({seed = seed, tutorial = false})
    p = Player.new(0, 0)
    w:addEntity(p)
    w:update(DT)
    check("level rises with distance from the start", w:levelForChunk(0, 1) == 1 and w:levelForChunk(6, 0) == 4,
        ("%d %d"):format(w:levelForChunk(0, 1), w:levelForChunk(6, 0)))

    -- Drone swarm keeps formation spacing while chasing
    w = World.new({spawnEnemies = false, tutorial = false})
    p = Player.new(200, 0)
    w:addEntity(p)
    local drones = {}
    for i = 1, 4 do
        local d = Enemy.new(0, 0, "ROBOTIC_DRONE")
        d.attackRange = 0
        table.insert(w.enemies, d); table.insert(drones, d)
    end
    for _ = 1, 30 do w:update(DT) end
    local minDist = math.huge
    for i = 1, #drones do
        for j = i + 1, #drones do
            minDist = math.min(minDist, math.sqrt((drones[i].x - drones[j].x) ^ 2 + (drones[i].y - drones[j].y) ^ 2))
        end
    end
    check("drones keep formation spacing", minDist >= 50 * 0.8, minDist)
    check("enemy debug rings are off by default", Enemy.debug == false)

    -- Weapons are per player; upgrades affect only the owner
    local pa, pb = Player.new(0, 0), Player.new(0, 0)
    local baseDamage = pb.weapons.laser_pistol.damage
    Loot.new(0, 0, "weapon_upgrade"):applyEffect(pa)  -- current weapon is the laser pistol
    check("weapon upgrade raises current weapon damage", pa.weapons.laser_pistol.damage == baseDamage + 5 and pa.weaponLevels.laser_pistol == 2,
        pa.weapons.laser_pistol.damage)
    check("upgrades do not leak to other players", pb.weapons.laser_pistol.damage == baseDamage and Player.new(0, 0).weapons.laser_pistol.damage == baseDamage)
    for _ = 1, 20 do pa:upgradeWeapon("plasma_rifle", 1) end
    check("weapon level is capped at 10", pa.weaponLevels.plasma_rifle == 10, pa.weaponLevels.plasma_rifle)

    -- Inventory
    p = Player.new(0, 0)
    check("materials go to the inventory", Loot.new(0, 0, "alien_essence"):applyEffect(p) and p:countItem("alien_essence") == 1)
    Loot.new(0, 0, "alien_essence"):applyEffect(p)
    check("same items stack in one slot", #p.inventory == 1 and p.inventory[1].count == 2, #p.inventory)
    check("health crystal at full health is kept", Loot.new(0, 0, "health_crystal"):applyEffect(p) and p:countItem("health_crystal") == 1 and p.health == 100)
    p.health = 40
    local slot
    for i, st in ipairs(p.inventory) do if st.type == "health_crystal" then slot = i end end
    check("using a health crystal from the inventory heals", p:useItem(slot) and p.health == 65 and p:countItem("health_crystal") == 0, p.health)
    check("materials cannot be used", p:useItem(1) == false and p:countItem("alien_essence") == 2)
    p.health = 30
    check("health crystal is used at once when hurt", Loot.new(0, 0, "health_crystal"):applyEffect(p) and p.health == 55 and p:countItem("health_crystal") == 0)
    local full = Player.new(0, 0)
    for _, t in ipairs({"alien_essence", "health_crystal", "energy_crystal", "shield_crystal", "repair_kit"}) do full:addItem(t) end
    for i = 1, 3 do full.inventory[#full.inventory + 1] = {type = "x" .. i, count = 1} end
    local leftover = Loot.new(0, 0, "weapon_upgrade")
    full.weaponLevels.laser_pistol = 10
    check("full inventory leaves the item on the ground", leftover:applyEffect(full) == false and not leftover.isCollected)
    w = World.new({spawnEnemies = false, tutorial = false})
    p = Player.new(0, 0)
    w:addEntity(p)
    p:addItem("alien_essence")
    check("dropping puts the item on the ground", w:dropItem(p, 1) and #w.loot == 1 and #p.inventory == 0)
    w:update(DT)
    check("dropped item is not picked straight back up", #p.inventory == 0 and #w.loot == 1)
    for _ = 1, 120 do w:update(DT) end
    p.x, p.y = w.loot[1] and w.loot[1].x or 0, w.loot[1] and w.loot[1].y or 0
    w:update(DT)
    check("dropped item can be picked up after the delay", p:countItem("alien_essence") == 1)

    -- Inventory slot hit test
    local UI = require("src.ui.ui")
    local ui = UI.new(p)
    ui.showInventory = true
    local sx, sy, sw, sh = ui:inventorySlotRect(3)
    check("inventory slot hit test", ui:inventorySlotAt(sx + sw / 2, sy + sh / 2) == 3 and ui:inventorySlotAt(-5, -5) == nil)

    -- Map: the 3x3 block around the player counts as explored, and the map draws
    w = World.new({spawnEnemies = false, tutorial = false})
    p = Player.new(0, 0)
    w:addEntity(p)
    w:update(DT)
    local seen = 0
    for _ in pairs(w.explored) do seen = seen + 1 end
    check("chunks around the player are explored", seen == 9, seen)
    ui = UI.new(p, w)
    ui.showMap = true
    local okMap, errMap = pcall(function() ui:draw() end)
    check("map draws without error", okMap, errMap)

    -- Save serializer
    local Save = require("src.save.save")
    local sample = {a = 1, b = -2.5, s = "quote \" and\nnewline", t = true, f = false, list = {3, 2, 1}, nested = {x = {y = "z"}}}
    local back = Save.deserialize(Save.serialize(sample))
    check("save serializer round-trips nested data", back and back.b == -2.5 and back.s == sample.s and back.f == false
        and back.list[3] == 1 and back.nested.x.y == "z")
    local bad1 = Save.deserialize("return os.exit()")
    local bad2 = Save.deserialize("while true do end return {}")
    local bad3 = Save.deserialize("return 42")
    check("tampered saves cannot call functions", bad1 == nil)
    check("runaway save code is stopped", bad2 == nil)
    check("non-table saves are rejected", bad3 == nil)

    -- Utils
    local Utils = require("src.utils.utils")
    local seenMin, seenMax = false, false
    for _ = 1, 500 do
        local v = Utils.randomInt(1, 3)
        if v == 1 then seenMin = true elseif v == 3 then seenMax = true end
        if v < 1 or v > 3 or v % 1 ~= 0 then seenMin = nil end
    end
    check("randomInt covers both ends", seenMin == true and seenMax == true)
    local hr, hg, hb = Utils.hexToRGB("#FF8000")
    check("hexToRGB returns 0-1 components", hr == 1 and math.abs(hg - 128 / 255) < 1e-9 and hb == 0)
    check("RGBToHex takes 0-1 components", Utils.RGBToHex(1, 128 / 255, 0) == "#FF8000", Utils.RGBToHex(1, 128 / 255, 0))
    local parts = Utils.split("a,b,,c", ",")
    local pct = Utils.split("10%20%30", "%")
    check("split skips empty fields", #parts == 3 and parts[3] == "c")
    check("split handles pattern characters", #pct == 3 and pct[2] == "20", #pct)
    check("trim, clamp, lerp, formatTime", Utils.trim("  hi  ") == "hi" and Utils.clamp(5, 0, 3) == 3
        and Utils.lerp(0, 10, 0.25) == 2.5 and Utils.formatTime(125) == "02:05")
    love.filesystem.write("debug.log", "")
    local okDebug = pcall(Utils.debugPrint, "x", 1, nil, true)
    local logged = love.filesystem.read("debug.log") or ""
    love.filesystem.remove("debug.log")
    check("debugPrint writes non-string values to debug.log", okDebug and logged:find("x 1 nil true", 1, true) ~= nil, logged)

    -- Travel rules
    local Session = require("src.game.session")
    local s = Session.new(1)
    check("can jump from Kepler Reach to Drift Station", (s:canTravel("drift_station")))
    local okFar, _, whyFar = s:canTravel("glacius")
    check("far planets are out of base jump range", not okFar and whyFar:find("range") ~= nil, whyFar)
    s:travel("drift_station")
    check("docking at the station refuels", s.fuel == s:maxFuel() and s.location == "drift_station")
    s.upgrades.jump_drive = true
    check("jump drive upgrade extends range", (s:canTravel("glacius")))
    s.location = "glacius"
    local okRift, _, whyRift = s:canTravel("the_rift")
    check("the Rift needs all fragments", not okRift and whyRift:find("fragments") ~= nil, whyRift)
    s.fragments = {cinder = true, glacius = true, verdant_deep = true}
    okRift, _, whyRift = s:canTravel("the_rift")
    check("the Rift needs void shielding", not okRift and whyRift:find("Void Shielding") ~= nil, whyRift)
    s.upgrades.void_shielding = true
    check("the Rift opens with fragments and shielding", (s:canTravel("the_rift")))
    s.location, s.fuel = "cinder", 0
    local okTow, towCost = s:canTravel("drift_station")
    check("out of fuel: free tow to Drift Station", okTow and towCost == 0)
    check("out of fuel: no other jumps", not (s:canTravel("kepler_reach")))
    local s2 = Session.fromSave(s:serialize())
    check("session survives save and load", s2.location == "cinder" and s2.fuel == 0 and s2:fragmentCount() == 3
        and s2:hasUpgrade("void_shielding") and s2.seed == s.seed)

    -- Bounded worlds and interactables
    w = World.new({spawnEnemies = false, tutorial = false, bounds = World.chunkBounds(1)})
    p = Player.new(5000, -5000)
    w:addEntity(p)
    w:update(DT)
    check("bounded worlds keep the player inside", p.x <= w.bounds.x1 - 20 and p.y >= w.bounds.y0 + 20, ("%.0f,%.0f"):format(p.x, p.y))
    local used = false
    w:addInteractable({x = 0, y = 0, radius = 50, onInteract = function() used = true end})
    check("nearest interactable within radius", w:nearestInteractable(10, 10) ~= nil and w:nearestInteractable(200, 200) == nil)

    -- Upgrades
    local Upgrades = require("src.game.upgrades")
    s = Session.new(5)
    p = Player.new(0, 0)
    local okBuy, whyNot = Upgrades.canBuy(s, p, "jump_drive")
    check("upgrades need materials", not okBuy and whyNot:find("Need") ~= nil, whyNot)
    for _ = 1, 5 do p:addItem("salvage") end
    p:addItem("alien_essence"); p:addItem("alien_essence")
    check("buying a ship upgrade takes payment", Upgrades.buy(s, p, "jump_drive") and s:hasUpgrade("jump_drive")
        and p:countItem("salvage") == 1 and p:countItem("alien_essence") == 0)
    check("an installed upgrade cannot be bought again", not (Upgrades.canBuy(s, p, "jump_drive")))
    for _ = 1, 3 do p:addItem("salvage") end
    p.health = 90
    check("armor plating raises max health", Upgrades.buy(s, p, "armor_plating") and p.maxHealth == 125 and p.health == 115,
        ("%s/%s"):format(p.health, p.maxHealth))
    p:heal(100)
    check("healing caps at the upgraded maximum", p.health == 125, p.health)
    Upgrades.applyToPlayer(s, p)
    check("applying upgrades again changes nothing", p.maxHealth == 125 and p.health == 125)
    p.shield = 0
    for _ = 1, 1500 do p:update(DT) end   -- 2 s delay, then 5 per second
    check("shield recharges to its own maximum", p.shield == p.maxShield, p.shield)
    check("removeItemsOfType refuses when short", p:removeItemsOfType("salvage", 99) == false)

    -- Vaults
    local Vault = require("src.world.vault")
    local function vaultWorld(puzzle)
        local vw = World.new({spawnEnemies = false, tutorial = false})
        local vp = Player.new(0, 0)
        vw:addEntity(vp)
        local result = {collected = false, notes = {}}
        result.vault = Vault.new(vw, {x = 0, y = 0, puzzle = puzzle, seed = 7,
            notify = function(text) table.insert(result.notes, text) end,
            onCollect = function() result.collected = true end})
        return vw, vp, result
    end

    -- Sequence: watch, then wake the pylons in order
    local vw, vp, r = vaultWorld("sequence")
    local v = r.vault
    v:useDoor()
    check("reading the glyphs plays the sequence", v.flashQueue ~= nil and #r.notes == 1)
    v:activatePylon(v.sequence[1])
    check("pylons ignore input during playback", v.progress == 0)
    for _ = 1, 400 do vw:update(DT) end
    check("sequence playback finishes", v.flashQueue == nil)
    v:activatePylon(v.sequence[1] % 4 + 1)
    check("wrong pylon resets and summons guardians", v.progress == 0 and #vw.enemies == 2, #vw.enemies)
    for _, index in ipairs(v.sequence) do
        local part = vw:findInteractable("pylon_" .. index)
        part.onInteract(part)
    end
    check("correct order opens the vault", v.solved)
    v:useDoor()
    check("taking the fragment from the open vault", v.collected and r.collected and vw:nearestInteractable(0, 0) == nil)

    -- Resonance: find a solution, then apply it by shooting the crystals
    vw, vp, r = vaultWorld("resonance")
    v = r.vault
    check("crystals start scrambled", not v:allCrystalsLit())
    local solution
    for mask = 1, 31 do
        for i = 1, 5 do if bit.band(mask, bit.lshift(1, i - 1)) ~= 0 then v:toggleCrystals(i) end end
        local lit = v:allCrystalsLit()
        for i = 1, 5 do if bit.band(mask, bit.lshift(1, i - 1)) ~= 0 then v:toggleCrystals(i) end end
        if lit then solution = mask; break end
    end
    check("the crystal puzzle is solvable", solution ~= nil)
    for i = 1, 5 do
        if solution and bit.band(solution, bit.lshift(1, i - 1)) ~= 0 then
            local crystal = v.crystals[i]
            vp.fireTimer = 0
            vp:fire(crystal.x, crystal.y)
            for _ = 1, 40 do vw:update(DT) end
        end
    end
    check("shooting the right crystals opens the vault", v.solved)

    -- Plates: walk onto plates whose numbers add up to the target
    vw, vp, r = vaultWorld("plates")
    v = r.vault
    local pick
    for mask = 1, 31 do
        local sum = 0
        for i = 1, 5 do if bit.band(mask, bit.lshift(1, i - 1)) ~= 0 then sum = sum + v.plates[i].value end end
        if sum == v.target then pick = mask; break end
    end
    for i = 1, 5 do
        if pick and bit.band(pick, bit.lshift(1, i - 1)) ~= 0 then
            vp.x, vp.y = v.plates[i].x, v.plates[i].y
            vw:update(DT)
            vp.x, vp.y = 0, -300
            vw:update(DT)
        end
    end
    check("standing on plates that match the target opens the vault", v.solved, ("target %d sum %d"):format(v.target, v:plateSum()))

    -- Vault state survives save and load
    local saved = vw:saveState()
    local vw2 = World.new({spawnEnemies = false, tutorial = false})
    local v2 = Vault.new(vw2, {x = 0, y = 0, puzzle = "plates", seed = 7})
    vw2:loadState(saved)
    check("vault state survives save and load", v2.solved and not v2.collected)
end

function love.load(args)
    REPO = args[1] or (love.filesystem.getSource() .. "/../..")
    OUT = args[2]
    package.path = REPO .. "/?.lua;" .. package.path

    local chunk = assert(loadfile(REPO .. "/main.lua"))
    chunk()
    game.load, game.update, game.draw = love.load, love.update, love.draw
    game.keypressed, game.mousepressed = love.keypressed, love.mousepressed

    -- Re-install harness callbacks over the game's
    love.update, love.draw = harnessUpdate, harnessDraw

    local ok, err = xpcall(runUnitTests, debug.traceback)
    check("unit tests ran without error", ok, err)

    -- love.load must leave the window as conf.lua configured it (no setMode override)
    local w0, h0, flags0 = love.window.getMode()
    game.load()
    local w1, h1, flags1 = love.window.getMode()
    check("love.load does not override the window mode", w0 == w1 and h0 == h1 and flags0.resizable == flags1.resizable,
        ("%dx%d resizable=%s -> %dx%d resizable=%s"):format(w0, h0, tostring(flags0.resizable), w1, h1, tostring(flags1.resizable)))
    sim.phase = "scenario"
end

local spawnSeen, killsAtSpawn, pausedCheckDone = false, nil, false
local tutorialDone = false

local function nearestEnemy(world, player)
    local best, bd
    for _, e in ipairs(world.enemies) do
        if not e.isDead then
            local d = (e.x - player.x) ^ 2 + (e.y - player.y) ^ 2
            if not bd or d < bd then best, bd = e, d end
        end
    end
    return best
end

local function step()
    sim.t = sim.t + DT
    local t = sim.t
    local s = state()
    local player, world = getPlayer(), getWorld()

    if sim.phase == "scenario" then
        if t < DT * 2 then game.keypressed("space") end

        -- Movement: hold D+S for one second, then release
        keysDown = {}
        if t > 0.5 and t < 1.5 then keysDown.d, keysDown.s = true, true end
        if math.abs(t - 1.0) < DT / 2 then
            local sp = math.sqrt(player.velocity.x ^ 2 + player.velocity.y ^ 2)
            check("WASD diagonal moves at normal speed in game", math.abs(sp - 200) < 0.01, sp)
        end
        -- Open and close the map and inventory so they get drawn during the run
        if math.abs(t - 2.0) < DT / 2 or math.abs(t - 2.2) < DT / 2 then game.keypressed("m") end
        if math.abs(t - 2.3) < DT / 2 or math.abs(t - 2.4) < DT / 2 then game.keypressed("i") end
        if math.abs(t - 2.1) < DT / 2 then
            check("map opens with M", upvalue(updateGame, "ui").showMap == true)
        end
        if math.abs(t - 1.7) < DT / 2 then
            check("player stops after keys released", player.velocity.x == 0 and player.velocity.y == 0)
        end
        if math.abs(t - 2.5) < DT / 2 then
            -- After moving, the camera has caught up and the player is near screen center
            local sx, sy = worldToScreen(player.x, player.y)
            local cx, cy = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
            check("camera follows the player", math.abs(sx - cx) < 5 and math.abs(sy - cy) < 5, ("%.1f,%.1f vs %.1f,%.1f"):format(sx, sy, cx, cy))
            local wx, wy = screenToWorld(worldToScreen(123.5, -456.25))
            check("screen/world conversion round-trips", math.abs(wx - 123.5) < 1e-6 and math.abs(wy + 456.25) < 1e-6)
        end

        -- Pause during tutorial and resume back into tutorial
        if not pausedCheckDone and t > 3 then
            game.keypressed("escape")
            local p1 = state()
            game.keypressed("escape")
            check("pause from tutorial resumes to tutorial", p1 == "paused" and state() == "tutorial", tostring(p1) .. "->" .. tostring(state()))
            pausedCheckDone = true
        end

        -- Fight once enemies exist, cycling weapons
        local e = nearestEnemy(world, player)
        if e then
            spawnSeen = true
            local weapons = {"1", "2", "3", "4", "5"}
            game.keypressed(weapons[math.floor(t / 2) % 5 + 1])
            -- Click where the enemy appears on screen (the game converts back to world coordinates)
            mouseX, mouseY = worldToScreen(e.x, e.y)
            game.mousepressed(mouseX, mouseY, 1)
        end

        if world.tutorial.completed and not tutorialDone then
            tutorialDone = true
            check("tutorial completes after defeating enemies", true)
            check("state switches to playing after tutorial", state() == "playing", state())
            sim.phase = "save"
        elseif t > 120 then
            check("tutorial completes after defeating enemies", false, ("t=%.1f spawn=%s state=%s step=%s enemies=%d health=%.0f"):format(t, tostring(spawnSeen), tostring(state()), tostring(world.tutorial.currentStep), #world.enemies, player.health))
            sim.phase = "death"
        end
        game.update(DT)
    elseif sim.phase == "save" then
        -- Save through the pause menu, change things, then load through the pause menu
        local Save = require("src.save.save")
        Save.delete()
        player:addItem("alien_essence"); player:addItem("alien_essence"); player:addItem("alien_essence")
        player:upgradeWeapon("plasma_rifle", 5)
        player.health = 77
        local savedX, savedY, savedSeed = player.x, player.y, world.seed
        local savedDamage = player.weapons.plasma_rifle.damage
        local exploredBefore = 0
        for _ in pairs(world.explored) do exploredBefore = exploredBefore + 1 end

        game.keypressed("escape")
        game.keypressed("down")                        -- Save Game
        game.keypressed("return")
        local u = upvalue(updateGame, "ui")
        check("pause menu saves the game", Save.exists() and u.menuMessage == "Game saved", tostring(u.menuMessage))

        player.health = 1
        player.inventory = {}
        player.x = player.x + 5000
        game.keypressed("down")                        -- Load Game
        game.keypressed("return")
        local np, nw = getPlayer(), getWorld()
        local exploredAfter = 0
        for _ in pairs(nw.explored) do exploredAfter = exploredAfter + 1 end
        check("load restores the player", np.health == 77 and np:countItem("alien_essence") == 3
            and np.weapons.plasma_rifle.damage == savedDamage and math.abs(np.x - savedX) < 1e-6 and math.abs(np.y - savedY) < 1e-6,
            ("hp=%s essence=%s dmg=%s"):format(np.health, np:countItem("alien_essence"), np.weapons.plasma_rifle.damage))
        check("load restores the world", nw.seed == savedSeed and exploredAfter == exploredBefore and exploredAfter > 0,
            ("seed %s/%s explored %d/%d"):format(nw.seed, savedSeed, exploredAfter, exploredBefore))
        check("load resumes play", state() == "playing", state())
        Save.delete()
        sim.phase = "travel"
    elseif sim.phase == "travel" then
        -- Walk to the ship, open the star map, jump to Drift Station and back
        player = getPlayer()
        local homeWorld = getWorld()
        local exploredHome = 0
        for _ in pairs(homeWorld.explored) do exploredHome = exploredHome + 1 end
        local ship = homeWorld:findInteractable("ship")
        player.x, player.y = ship.x + 10, ship.y
        game.update(DT)
        check("ship shows an interaction prompt", upvalue(updateGame, "ui").prompt ~= nil)
        game.keypressed("e")
        check("E at the ship opens the star map", state() == "starmap", state())
        local map = getStarMap()
        local function selectLocation(id)
            for _ = 1, 8 do
                if map:selectedLocation().id == id then return true end
                game.keypressed("right")
            end
            return false
        end
        selectLocation("drift_station")
        game.keypressed("return")
        local sess = getSession()
        check("jump to Drift Station", state() == "playing" and sess.location == "drift_station" and getWorld() ~= homeWorld,
            tostring(sess.location))
        check("fuel is full after docking", sess.fuel == sess:maxFuel(), sess.fuel)
        player = getPlayer()
        player.x = 99999
        game.update(DT)
        check("station deck bounds hold the player", player.x < 2000, player.x)

        -- Buy armor at the upgrade terminal
        local terminal = getWorld():findInteractable("terminal")
        check("the station has an upgrade terminal", terminal ~= nil)
        for _ = 1, 4 do player:addItem("salvage") end
        player.x, player.y = terminal.x, terminal.y
        game.keypressed("e")
        check("E at the terminal opens the shop", state() == "shop", state())
        local shopUi = upvalue(openShop, "shop")
        while shopUi:selectedUpgrade().id ~= "armor_plating" do game.keypressed("down") end
        game.keypressed("return")
        check("buying armor at the terminal", sess:hasUpgrade("armor_plating") and player.maxHealth == 125 and player:countItem("salvage") == 0,
            tostring(shopUi.message))
        game.keypressed("escape")
        check("Esc closes the shop", state() == "playing", state())

        local stationShip = getWorld():findInteractable("ship")
        player.x, player.y = stationShip.x, stationShip.y
        game.keypressed("e")
        selectLocation("the_rift")
        game.keypressed("return")
        check("the Rift is locked at the start", state() == "starmap" and (map.message or ""):find("fragments") ~= nil, tostring(map.message))
        selectLocation("kepler_reach")
        game.keypressed("return")
        local exploredBack = 0
        for _ in pairs(getWorld().explored) do exploredBack = exploredBack + 1 end
        check("returning keeps the planet as it was", getWorld() == homeWorld and exploredBack >= exploredHome and sess.fuel == sess:maxFuel() - 1,
            ("explored %d/%d fuel %d"):format(exploredBack, exploredHome, sess.fuel))
        
        -- Fly to Cinder by way of Drift Station and take its fragment
        local function boardAndJump(id)
            local shipHere = getWorld():findInteractable("ship")
            player = getPlayer()
            player.x, player.y = shipHere.x, shipHere.y
            game.keypressed("e")
            selectLocation(id)
            game.keypressed("return")
        end
        boardAndJump("drift_station")
        boardAndJump("cinder")
        local cinder = getWorld()
        check("Cinder has a sequence vault", sess.location == "cinder" and cinder.vault ~= nil and cinder.vault.puzzle == "sequence")
        local salvageBefore = getPlayer():countItem("salvage")
        cinder.vault:setSolved()
        cinder.vault:useDoor()
        check("taking a fragment updates the campaign", sess.fragments.cinder == true and sess:fragmentCount() == 1
            and getPlayer():countItem("salvage") == salvageBefore + 3, sess:fragmentCount())
        sim.phase = "death"
    elseif sim.phase == "death" then
        player = getPlayer()
        player.health = 0
        game.update(DT)
        check("zero health triggers game over", state() == "game_over", state())
        game.keypressed("r")
        check("R returns to menu after game over", state() == "menu", state())
        check("restart gives a fresh player", getPlayer().health == 100, getPlayer().health)
        sim.phase = "done"
    end
end

function harnessUpdate(dt)
    for _ = 1, 30 do
        if sim.phase == "done" then break end
        local ok, err = xpcall(step, debug.traceback)
        if not ok then
            check("scenario ran without error", false, err)
            sim.phase = "done"
        end
    end
    if sim.phase == "done" then
        flush()
        love.event.quit(failures == 0 and 0 or 1)
    end
end

function harnessDraw()
    local ok, err = xpcall(game.draw, debug.traceback)
    if not ok then
        check("draw ran without error (state " .. tostring(state()) .. ")", false, err)
        sim.phase = "done"
    end
end

function love.errorhandler(msg)
    log("FAIL uncaught error :: " .. tostring(msg) .. "\n" .. debug.traceback())
    failures = failures + 1
    flush()
end
