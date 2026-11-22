function love.conf(t)
    t.identity = "last_starchart"        -- The name of the save directory
    t.version = "11.4"                     -- The LÖVE version this game was made for
    t.console = true                       -- Enable the console (useful for debugging)
    
    t.window.title = "The Last Starchart"    -- The window title
    t.window.icon = nil                    -- Filepath to an image to use as the window's icon
    t.window.width = 1280                  -- The window width
    t.window.height = 720                  -- The window height
    t.window.borderless = false            -- Remove all border visuals from the window
    t.window.resizable = true              -- Let the window be user-resizable
    t.window.minwidth = 800                -- Minimum window width if the window is resizable
    t.window.minheight = 600               -- Minimum window height if the window is resizable
    t.window.fullscreen = false            -- Enable fullscreen
    t.window.fullscreentype = "desktop"    -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode
    t.window.vsync = 1                     -- Vertical sync mode (0 to disable vsync, 1 to enable, -1 for adaptive vsync)
    t.window.msaa = 0                      -- The number of samples to use with multi-sampled antialiasing
    t.window.depth = nil                   -- The number of bits per sample in the depth buffer
    t.window.stencil = nil                 -- The number of bits per sample in the stencil buffer
    t.window.display = 1                   -- Index of the monitor to show the window in
    t.window.highdpi = false               -- Enable high-dpi mode for the window on a Retina display
    t.window.usedpiscale = true            -- Enable automatic DPI scaling
    t.window.x = nil                       -- The x-coordinate of the window's position in the specified display
    t.window.y = nil                       -- The y-coordinate of the window's position in the specified display
    
    t.modules.audio = true                 -- Enable the audio module
    t.modules.data = true                  -- Enable the data module
    t.modules.event = true                 -- Enable the event module
    t.modules.font = true                  -- Enable the font module
    t.modules.graphics = true              -- Enable the graphics module
    t.modules.image = true                 -- Enable the image module
    t.modules.joystick = true              -- Enable the joystick module
    t.modules.keyboard = true              -- Enable the keyboard module
    t.modules.math = true                  -- Enable the math module
    t.modules.mouse = true                 -- Enable the mouse module
    t.modules.physics = true               -- Enable the physics module
    t.modules.sound = true                 -- Enable the sound module
    t.modules.system = true                -- Enable the system module
    t.modules.thread = true                -- Enable the thread module
    t.modules.touch = true                 -- Enable the touch module
    t.modules.timer = true                 -- Enable the timer module
end 