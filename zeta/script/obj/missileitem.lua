local class = require 'ext.class'
local AmmoItem = require 'zeta.script.obj.ammoitem'
local MissileItem = class(AmmoItem)
MissileItem.sprite = 'missile'
MissileItem.angle = 90
MissileItem.rotCenter = {0,.5}
MissileItem.drawCenter = {0,.5}
MissileItem.ammo = 'Missiles'
return MissileItem
