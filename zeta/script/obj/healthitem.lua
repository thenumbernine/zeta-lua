local Item = require 'zeta.script.obj.item'
local HealthItem = class(Item)
HealthItem.sprite = 'heart'
HealthItem.invSeq = 'stand1'	-- stop flashing!

function HealthItem:init(...)
	HealthItem.super.init(self, ...)
	local game = require 'base.script.singleton.game'
	self.removeTime = game.time + 10
end

HealthItem.useGravity = false
function HealthItem:touch(other)
	if self.remove then return end
	if not other:isa(require 'zeta.script.obj.hero') then return true end
	other.health = math.min(other.health + 1, other.maxHealth)
	self:playSound('powerup')
	self.remove = true
end

return HealthItem
