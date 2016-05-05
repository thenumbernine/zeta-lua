local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'

local Heart = class(Item)
Heart.sprite = 'heart'
Heart.invSeq = 'stand1'	-- stop flashing!

function Heart:init(...)
	Heart.super.init(self, ...)
--	setTimeout(60, function() self.remove = true end)
end

function Heart:onUse(player)
	player.health = math.min(player.health + 1, player.maxHealth)
	self:playSound('powerup')
	self.remove = true
end

return Heart
