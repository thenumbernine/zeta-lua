local AmmoMaxItem = require 'zeta.script.obj.ammomaxitem'
local GrenadeItem = class(AmmoMaxItem)
GrenadeItem.sprite = 'grenade'
GrenadeItem.ammo = 'Grenades'

--[[ for the old, shootable version:
GrenadeItem.shotSpeed = 11
GrenadeItem.shotUpSpeed = 8
GrenadeItem.shotSound = nil
GrenadeItem.drawOffsetStanding = {.625, .5}
GrenadeItem.drawOffsetDucking = {.625, .25}
now that grenades are ammo numbers, how do I make them throwable? 
--]]

return GrenadeItem
