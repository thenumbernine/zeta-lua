local AmmoMaxItem = require 'zeta.script.obj.ammomaxitem'
local GrenadeMaxItem = class(AmmoMaxItem)
GrenadeMaxItem.sprite = 'grenade'
GrenadeMaxItem.ammo = 'Grenades'

--[[ for the old, shootable version:
GrenadeMaxItem.shotSpeed = 11
GrenadeMaxItem.shotUpSpeed = 8
GrenadeMaxItem.shotSound = nil
GrenadeMaxItem.drawOffsetStanding = {.625, .5}
GrenadeMaxItem.drawOffsetDucking = {.625, .25}
now that grenades are ammo numbers, how do I make them throwable? 
--]]

return GrenadeMaxItem
