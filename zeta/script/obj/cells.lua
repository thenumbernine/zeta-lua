local class = require 'ext.class'
local ItemBonus = require 'zeta.script.obj.itembonus'

local Cells = class(ItemBonus)
Cells.sprite = 'cells'
Cells.invSeq = 'stand5'
Cells.cells = 1

function Cells:init(args)
	Cells.super.init(self, args)
	self.cells = args.cells
end

function Cells:onGiveBonus(player)
	player.maxAmmoCells = player.maxAmmoCells + self.cells
end

return Cells
