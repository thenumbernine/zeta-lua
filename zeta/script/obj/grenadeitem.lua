local class = require 'ext.class'
local GrenadeLauncher = require 'zeta.script.obj.grenadelauncher'
local Item = require 'zeta.script.obj.item'

local GrenadeItem = class(Item)
GrenadeItem.sprite = 'grenade'
GrenadeItem.playerHoldOffsetStanding = {.625, .5}
GrenadeItem.playerHoldOffsetDucking = {.625, .25}

function GrenadeItem:onUse(player)
	self.remove = true
	-- create a temp obj to skip the constructor 
	-- don't give this to the player
	-- TODO flag to say "don't add to game.objs" ? maybe not...
	local temp = setmetatable({
		heldby = player,
	}, GrenadeLauncher)
	temp:doUpdateHeldPosition()
	temp:onShoot(player)
end

return GrenadeItem
