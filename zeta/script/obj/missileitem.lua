local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'

local MissileItem = class(Item)
MissileItem.sprite = 'missile'
MissileItem.angle = 90
MissileItem.rotCenter = {0,.5}

-- TODO better draw size, offset, rotation center, etc
function MissileItem:draw(...)
	self.pos[1] = self.pos[1] + .5
	self.pos[2] = self.pos[2] - .25
	MissileItem.super.draw(self, ...)
	self.pos[1] = self.pos[1] - .5
	self.pos[2] = self.pos[2] + .25
end

return MissileItem
