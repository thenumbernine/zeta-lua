local class = require 'ext.class'
local ItemBonus = require 'zeta.script.obj.itembonus'

local EnergyTank = class(ItemBonus)
EnergyTank.sprite = 'crystal'
EnergyTank.healthBonus = 1

function EnergyTank:onGiveBonus(player)
	player.maxHealth = player.maxHealth + self.healthBonus
	player.health = player.health + self.healthBonus
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
