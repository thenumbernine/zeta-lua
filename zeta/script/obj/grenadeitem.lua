local class = require 'ext.class'
local Weapon = require 'zeta.script.obj.weapon'
local GrenadeLauncher = require 'zeta.script.obj.grenadelauncher'

local GrenadeItem = class(GrenadeLauncher)
GrenadeItem.sprite = 'grenade'
GrenadeItem.shotSpeed = 11
GrenadeItem.shotUpSpeed = 8
GrenadeItem.shotSound = nil
GrenadeItem.drawOffsetStanding = {.625, .5}
GrenadeItem.drawOffsetDucking = {.625, .25}

return GrenadeItem
