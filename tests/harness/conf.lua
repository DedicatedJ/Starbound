-- Test harness configuration.
function love.conf(t)
    t.identity = "starbound_legacy_tests"   -- separate save folder so tests never touch real saves
    t.console = false
    t.window.title = "Starbound Legacy tests"
    t.window.width = 1280
    t.window.height = 720
    t.window.vsync = 0                      -- run frames as fast as possible
    -- No audio: CI machines have no sound device, and the tests do not need it
    t.modules.audio = false
    t.modules.sound = false
end
