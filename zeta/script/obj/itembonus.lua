-- bonus items are temp powerups 
local Item = require 'zeta.script.obj.item'
local game = require 'base.script.singleton.game'
local ItemBonus = class(Item)

function ItemBonus:playerGrab(player)
	-- don't skip Item:playerGrab because that's what unlinks us from our spawnInfos
	ItemBonus.super.playerGrab(self, player)
	
	self:playSound('powerup')
	self.remove = true	
	self:onGiveBonus(player)
end

return ItemBonus
