local class = require 'ext.class'
local math = require 'ext.math'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local function addTakesDamage(classObj)
	classObj.health = classObj.health or 1
	classObj.maxHealth = classObj.health
	classObj.invincibleEndTime = -1

	function classObj:takeDamage(damage, inflicter, attacker, side)
		if self.invincibleEndTime >= game.time then return end
		
		local FloatText = require 'zeta.script.obj.floattext'
		FloatText{pos=self.pos, text=tostring(damage)}
		
		self.health = math.clamp(self.health - damage, 0, self.maxHealth)
		if damage >= 0 then
			if self.health > 0 then 
				self:hit(damage, inflicter, attacker, side)
			else
				self:playSound('explode1')
				self:die(damage, inflicter, attacker, side)
			end
		end
	end

	function classObj:die()
		self.remove = true
		self:playSound('explode2')
	end
end

return addTakesDamage
