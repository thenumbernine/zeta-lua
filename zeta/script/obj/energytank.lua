local class = require 'ext.class'
local ItemBonus = require 'zeta.script.obj.item'

local EnergyTank = class(ItemBonus)
EnergyTank.healthBonus = 1
EnergyTank.sprite = 'crystal'

-- use upon grab
function EnergyTank:playerGrab(player, side)
	player.maxHealth = player.maxHealth + self.healthBonus
	player.health = player.health + self.healthBonus
	self:playSound('powerup')
	self.remove = true
end

function EnergyTank:draw(...)
	self.drawMirror = true
	EnergyTank.super.draw(self, ...)
	self.drawMirror = false
	self.sprite = 'heart'
	EnergyTank.super.draw(self, ...)
	self.sprite = nil
	EnergyTank.super.draw(self, ...)
end

return EnergyTank
