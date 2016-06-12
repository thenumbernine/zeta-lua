local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local Solid = class(Object)

Solid.useGravity = false
Solid.pushPriority = math.huge
Solid.solidFlags = Solid.SOLID_WORLD
Solid.touchFlags = 0
Solid.blockFlags = 0

return Solid
