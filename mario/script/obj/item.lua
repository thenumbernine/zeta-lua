local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local Mario = require 'mario.script.obj.mario'

--[[
itemClass is the class of the MarioItem that touching this gives you
--]]

local ItemObject = class(GameObject)
ItemObject.solid = false

function ItemObject:touch(other, side)
	if other:isa(Mario) then
		other:growBig()
		if self.itemClass then other.item = self:itemClass() end
		self.remove = true
	end
end


return ItemObject
