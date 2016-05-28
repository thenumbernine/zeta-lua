local class = require 'ext.class'
local AmmoTank = require 'zeta.script.obj.ammotank'

local MissileItem = class(AmmoTank)
MissileItem.sprite = 'missile'
MissileItem.angle = 90
MissileItem.rotCenter = {0,.5}
MissileItem.drawCenter = {0,.5}
MissileItem.ammo = 'Missiles'

return MissileItem
