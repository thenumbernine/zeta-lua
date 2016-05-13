-- bonus items are temp powerups 
local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'
local vec2 = require 'vec.vec2'
local game = require 'base.script.singleton.game'

local ItemBonus = class(Item)

function ItemBonus:playerGrab(player)
	self:playSound('powerup')
	self.remove = true	
	self:onGiveBonus(player)
end

return ItemBonus
