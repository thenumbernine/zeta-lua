local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local function addTakesDamage(classObj)
	classObj.health = classObj.health or 1
	classObj.invincibleEndTime = -1

	function classObj:takeDamage(damage, inflicter, attacker, side)
		if self.invincibleEndTime >= game.time then return end

		local gui = require 'base.script.singleton.gui'
		local tick = Object{
			pos = self.pos,
		}
		tick.solid = false
		tick.collidesWithWorld = false
		tick.collidesWithObjects = false
		tick.removeTime = game.time + 1
		tick.vel[2] = 1
		tick.useGravity = false
		tick.draw = function(self, R)
			gui.font:drawUnpacked(self.pos[1], self.pos[2]+2, 1, -1, tostring(damage))
			-- gui hasn't been R-integrated yet ...
			local gl = R.gl
			gl.glEnable(gl.GL_TEXTURE_2D)
		end
		
		self.health = math.max(0, self.health - damage)
		if self.health > 0 then 
			self:hit(damage, inflicter, attacker, side)
		else
			self:playSound('explode1')
			self:die(damage, inflicter, attacker, side)
		end
	end

	function classObj:die()
		self.remove = true
	end
end

return addTakesDamage
