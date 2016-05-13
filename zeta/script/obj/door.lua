local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local box2 = require 'vec.box2'

local Door = class(Door)
Door.sprite = 'door'
Door.solid = true
Door.useGravity = false
Door.pushPriority = math.huge
Door.bbox = box2(-.5, 0, .5, 2)

return Door
