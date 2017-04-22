return function(parentClass)

	local game = require 'base.script.singleton.game'
	local KickableTemplate = class(parentClass)

	KickableTemplate.kickHandicapTime = -2
	KickableTemplate.canCarry = true

	-- default touch routine: player precedence
	function KickableTemplate:touch(other, side)
		-- kick ignore 
		if other == self.kickedBy and self.kickHandicapTime >= game.time then
			return true
		end
		if KickableTemplate.super.touch then
			return KickableTemplate.super.touch(self, other, side)
		end
	end
	
	function KickableTemplate:hasBeenKicked(other)
		self.kickedBy = other
		self.kickHandicapTime = game.time + .5
	end

	function KickableTemplate:playerKick(other, dx, dy)
		local holderLookDir = 0
		if other.drawMirror then
			holderLookDir = -1
		else
			holderLookDir = 1
		end
		--self.pos[1] = other.pos[1] + holderLookDir
		if dy > 0 then	-- kick up
			self.vel[2] = self.vel[2] + 40
		elseif dy >= 0 and dx ~= 0	then	-- kicking and not setting down
			self.vel[2] = self.vel[2] + 6
			self.vel[1] = self.vel[1] + holderLookDir * 10
		else	-- setting down
			self.vel[2] = self.vel[2] + 4
			self.vel[1] = self.vel[1] + holderLookDir * 4
		end
		
		self:hasBeenKicked(other)
	end

	return KickableTemplate
end
