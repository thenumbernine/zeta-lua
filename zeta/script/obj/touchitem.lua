local Item = require 'zeta.script.obj.item'
local TouchItem = class(Item)
TouchItem.useGravity = false
TouchItem.duration = 10

function TouchItem:init(...)
	TouchItem.super.init(self, ...)
	local game = require 'base.script.singleton.game'
	self.removeTime = game.time + self.duration
end

function TouchItem:touch(other)
	if self.remove then return end
	if not other:isa(require 'zeta.script.obj.hero') then return true end
	self:playSound('powerup')
	self.remove = true
	
	-- same as BonusItem's callback.  
	-- hopefully that won't be a problem.
	-- I can't imagine an item being touch-to-get and pickup-to-get
	-- maybe I should get rid of pickup items altogether
	self:onGiveBonus(other)
end

return TouchItem
