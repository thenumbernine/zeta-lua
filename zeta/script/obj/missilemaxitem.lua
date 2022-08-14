local class = require 'ext.class'
local AmmoMaxItem = require 'zeta.script.obj.ammomaxitem'
local MissileMaxItem = class(AmmoMaxItem)
MissileMaxItem.sprite = 'missile'
MissileMaxItem.angle = 90
MissileMaxItem.rotCenter = {0,.5}
MissileMaxItem.drawCenter = {0,.5}
MissileMaxItem.ammo = 'Missiles'
return MissileMaxItem
