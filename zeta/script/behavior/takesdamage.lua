local class = require 'ext.class'
local game = require 'base.script.singleton.game'

local function takesDamageBehavior(parentClass)
	local TakesDamageTemplate = class(parentClass)

	TakesDamageTemplate.invincibleEndTime = -1

	function TakesDamageTemplate:init(...)
		TakesDamageTemplate.super.init(self, ...)
		-- start out with full health, if health wasn't already explicitly specified and maxHealth was
		assert(self.health or self.maxHealth, "you need to provide either health or maxHealth")
		if self.maxHealth and not self.health then
			self.health = self.maxHealth
		end
	end
	
	TakesDamageTemplate.showDamageAmount = 0
	TakesDamageTemplate.showDamageTime = -1
	function TakesDamageTemplate:showDamage()
		local FloatText = require 'zeta.script.obj.floattext'
		FloatText{pos=self.pos, text=tostring(self.showDamageAmount)}
		self.showDamageAmount = 0
		self.showDamageTime = -1
	end
	
	function TakesDamageTemplate:update(dt, ...)
		if (self.remove and self.showDamageAmount > 0)
		or (self.showDamageTime >= game.time - dt	-- last time
		and self.showDamageTime < game.time)
		then
			self:showDamage()
		end
		TakesDamageTemplate.super.update(self, dt, ...)
	end

	TakesDamageTemplate.showDamageDelay = .25
	function TakesDamageTemplate:takeDamage(damage, attacker, inflicter, side)
		if self.invincibleEndTime >= game.time then return end
		if self.dead then return end

		if attacker and attacker.modifyDamageGiven then
			damage = attacker:modifyDamageGiven(damage, self, inflicter, side) or damage
		end
		if self.modifyDamageTaken then
			damage = self:modifyDamageTaken(damage, attacker, inflicter, side) or damage
		end	
		
		-- accum damage before showing it
		self.showDamageTime = game.time + self.showDamageDelay 
		self.showDamageAmount = self.showDamageAmount + damage

		self.health = math.max(self.health - damage, 0)
		if self.maxHealth and self.health > self.maxHealth then
			self.health = self.maxHealth
		end
		if damage >= 0 then
			if self.health > 0 then 
				if self.hit then
					self:hit(damage, attacker, inflicter, side)
				end
			else
				self:die(damage, attacker, inflicter, side)
			end
		end
		
		if self.remove then self:showDamage() end
	end

	TakesDamageTemplate.painSound = 'explode1'
	function TakesDamageTemplate:hit(damage, attacker, inflicter, side)
		if self.painSound then self:playSound(self.painSound) end
	end

	TakesDamageTemplate.deathSound = 'explode2'
	TakesDamageTemplate.removeOnDie = true
	function TakesDamageTemplate:die(damage, attacker, inflicter, side)
		self.dead = true
		if self.onDie then
			local sandbox = require 'base.script.singleton.sandbox'
			sandbox(self.onDie,
				'self, damage, attacker, inflicter, side',
				self, damage, attacker, inflicter, side)
		end
		if self.deathSound then self:playSound(self.deathSound) end
		if self.removeOnDie then self.remove = true end
	end

	return TakesDamageTemplate
end

return takesDamageBehavior
