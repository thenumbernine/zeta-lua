local AmmoMaxItem = require 'zeta.script.obj.ammomaxitem'
local MissileItem = class(AmmoMaxItem)
MissileItem.sprite = 'missile'
MissileItem.angle = 90
MissileItem.rotCenter = {0,.5}
MissileItem.drawCenter = {0,.5}
MissileItem.ammo = 'Missiles'
return MissileItem
