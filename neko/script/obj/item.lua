local Neko = require 'neko.script.obj.neko'

--[[
itemClass is the class of the MarioItem that touching this gives you
--]]

local Item = require 'base.script.obj.object':subclass()
Item.solidFlags = Item.SOLID_NO
Item.canCarry = true
Item.canSwing = true

function Item:update(...)
	if self.inInventory then return end

	Item.super.update(self, ...)

	local heldby = self.heldby
	local spawnInfo = self.spawnInfo
	if spawnInfo then
		if heldby then
			-- pull heldby towards origin
			local s = .1
			local dx = spawnInfo.pos[1] - heldby.pos[1]
			local dy = spawnInfo.pos[2] - heldby.pos[2]
			heldby.pos[1] = heldby.pos[1] + s * dx
			heldby.pos[2] = heldby.pos[2] + s * dy
			heldby.vel[1] = heldby.vel[1] + dx * .1
			heldby.vel[2] = heldby.vel[2] + dy * .1
			heldby.vel[1] = heldby.vel[1] * .9
			heldby.vel[2] = heldby.vel[2] * .9
		else
			self.vel[1] = 0
			self.vel[2] = 0
			local s = .3
			self.pos[1] = self.pos[1] * (1 - s) + spawnInfo.pos[1] * s
			self.pos[2] = self.pos[2] * (1 - s) + spawnInfo.pos[2] * s
		end
	end
end

function Item:draw(...)
	if self.inInventory then return end
	Item.super.draw(self, ...)
end

return Item
