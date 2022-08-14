local class = require 'ext.class'
local AmmoMaxItem = require 'zeta.script.obj.ammomaxitem'
local CellMaxItem = class(AmmoMaxItem)
CellMaxItem.sprite = 'cells'
CellMaxItem.ammo = 'Cells'
return CellMaxItem
