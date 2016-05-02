local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'

local Heart = class(Item)
Heart.sprite = 'heart'
Heart.useGravity = false
Heart.solid = false

function Heart:init(...)
	Heart.super.init(self, ...)
	setTimeout(3, function() self.remove = true end)
end

function Heart:give(player, side)
	player.health = math.min(player.health + 1, player.maxHealth)
end

return Heart
