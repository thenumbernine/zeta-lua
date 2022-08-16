local class = require 'ext.class'
local dirs = require 'base.script.dirs'
local vec2 = require 'vec.vec2'
local SpritePieces = require 'zeta.script.obj.spritepieces'

local deathToPiecesBehavior = function(parentClass)
	local DeathToPiecesTemplate = class(parentClass)
	
	DeathToPiecesTemplate.deathPieceDivs = {4,4}
	function DeathToPiecesTemplate:die(damage, attacker, inflicter, side)
		local dir = attacker and attacker.pos and (self.pos - attacker.pos):normalize() or dirs[side] or vec2(0,0)
		SpritePieces.makeFrom{
			obj=self,
			dir=dir,
			divs=self.deathPieceDivs,
		}
		return DeathToPiecesTemplate.super.die(self, damage, attacker, inflicter, side)
	end

	return DeathToPiecesTemplate
end

return deathToPiecesBehavior
