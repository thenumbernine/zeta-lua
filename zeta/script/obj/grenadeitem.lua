local class = require 'ext.class'
local AmmoItem = require 'zeta.script.obj.ammoitem'
local GrenadeItem = class(AmmoItem)
GrenadeItem.sprite = 'grenade'
GrenadeItem.ammo = 'Grenades'
return GrenadeItem
