local class = require 'ext.class'
local Level = require 'base.script.level'

local ZetaLevel = class(Level)

--[[
-- only spawn the player ... and whatever's close to him
-- then, as the player moves, spawn things just out of his screen
function Level:initialSpawn()
end
--]]

return ZetaLevel
