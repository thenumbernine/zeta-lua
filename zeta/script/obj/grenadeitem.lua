local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'
local GrenadeLauncher = require 'zeta.script.obj.grenadelauncher'

local GrenadeItem = class(Item)
GrenadeItem.sprite = 'grenade'
GrenadeItem.playerHoldOffsetStanding = {.625, .5}
GrenadeItem.playerHoldOffsetDucking = {.625, .25}

-- make an object to launch the grenades - subclass of weapon
local GrenadeThrower = class(GrenadeLauncher)
GrenadeThrower.shotSpeed = 11
GrenadeThrower.shotUpSpeed = 8
GrenadeThrower.shotSound = nil
-- but override its init so it doesn't link to the game 
--  and is immediately thrown away
function GrenadeThrower:init(player)
	self.heldby = player
end

function GrenadeItem:onUse(player)
	self.remove = true
	-- create a temp obj to do the shooting
	--  so we don't have to give the item to the player
	-- technically GrenadeItem could be a Weapon and do this? 
	-- ... better, make all grenades pick-up-able ... 
	local temp = GrenadeThrower(player)
	temp:doUpdateHeldPosition()
	temp:onShoot(player)
end

return GrenadeItem
