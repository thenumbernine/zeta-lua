-- PowerupItem are items that have to be picked up 
local Item = require 'zeta.script.obj.item'
local game = require 'base.script.singleton.game'
local PowerupItem = class(Item)

function PowerupItem:playerGrab(player)
	-- don't skip Item:playerGrab because that's what unlinks us from our spawnInfos
	PowerupItem.super.playerGrab(self, player)
	self:playSound('powerup')
	self.remove = true	
	
	self:onGiveBonus(player)
end

return PowerupItem
