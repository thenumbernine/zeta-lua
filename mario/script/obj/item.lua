local Mario = require 'mario.script.obj.mario'

--[[
itemClass is the class of the MarioItem that touching this gives you
--]]

local Item = require 'base.script.obj.object':subclass()
Item.solidFlags = Item.SOLID_NO

function Item:touch(other, side)
	if Mario:isa(other) then
		other:growBig()
		if self.itemClass then other.item = self:itemClass() end
		self.remove = true
	end
end


return Item
