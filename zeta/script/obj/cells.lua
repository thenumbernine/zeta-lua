local class = require 'ext.class'
local AmmoTank = require 'zeta.script.obj.ammotank'
local Cells = class(AmmoTank)
Cells.sprite = 'cells'
Cells.invSeq = 'stand5'
Cells.ammo = 'Cells'
return Cells
