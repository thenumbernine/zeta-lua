local Missile = (function()
	local class = require 'ext.class'
	local Object = require 'base.script.obj.object'
	local game = require 'base.script.singleton.game'
	local MissileBlast = require 'zeta.script.obj.missileblast'
	local Puff = require 'zeta.script.obj.puff'
	local vec2 = require 'vec.vec2'
	local box2 = require 'vec.box2'

	local Missile = class(Object)
	Missile.bbox = box2(-.1, 0, .1, .2)
	Missile.sprite = 'missile'
	Missile.solid = false
	Missile.useGravity = false
	Missile.damage = 5
	Missile.splashDamage = 3
	Missile.rotCenter = {.5, .5}

	function Missile:init(...)
		Missile.super.init(self, ...)
	
		self.shooter:hasKicked(self)
		self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
	end

	function Missile:update(dt)
		Missile.super.update(self, dt)
		self.tick = ((self.tick or 0) + 1) % 3
		if self.tick == 0 then
			Puff{pos=self.pos + vec2(0,-.5)}
		end
	end

	function Missile:pretouch(other, side)
		if self.remove then return end
		local Item = require 'zeta.script.obj.item'
		if other:isa(Item) then return end
		if other == self.shooter then return true end
		local hit
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
			hit = true
		end
		if hit or other.solid then
			self:blast(other)
			return
		end
		return true
	end

	function Missile:touchTile(tile, side)
		if tile and tile.onHit then
			tile:onHit(self, side)
		end
		self:blast()
	end

	Missile.solidFlags = Missile.SOLID_GRENADE
	Missile.touchFlags = Missile.SOLID_WORLD 
						+ Missile.SOLID_YES 
						+ Missile.SOLID_NO 
						+ Missile.SOLID_GRENADE
	Missile.blockFlags = Missile.SOLID_WORLD
	function Missile:touchTile_v2(tile, solid)
		if self.remove then return true end
		self:blast()
	end
	function Missile:touch_v2(other, side)
		if self.remove then return true end
		if other == self.shooter then return true end
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
			self:blast(other)
			return
		end
		-- if it blocks us then cause an explosion
		-- TODO determine block before touch, and allow touch to modify it?
		if bit.band(other.solidFlags, self.blockFlags) == 0 then
			return true
		end
		self:blast(other)
	end

	function Missile:blast(alreadyHit)
		if self.remove then return end
		
		-- splash damage 
		-- TODO ignore objects just hit by damage?
		for _,other in ipairs(game.objs) do
			if other.takeDamage and other ~= alreadyHit then
				local delta = other.pos - self.pos
				if delta:length() < 2 then
				-- TODO and traceline ...
					other:takeDamage(self.splashDamage, self.shooter, self, side)
				end
			end
		end

		Puff.puffAt(self.pos[1], self.pos[2]-.5)
		MissileBlast{pos={self.pos[1], self.pos[2]-.5}}
		self:playSound('explode2')
		self.remove = true
	end
	
	return Missile
end)()

local MissileLauncher = (function()
	local class = require 'ext.class'
	local Weapon  = require 'zeta.script.obj.weapon'
	
	local MissileLauncher = class(Weapon)
	MissileLauncher.sprite = 'missilelauncher'
	MissileLauncher.shotDelay = .5
	MissileLauncher.shotSpeed = 50
	MissileLauncher.shotSound = 'explode1'
	MissileLauncher.rotCenter = {.25,.5}
	MissileLauncher.shotClass = Missile 

	function MissileLauncher:canShoot(player)
		if not MissileLauncher.super.canShoot(self, player) then return end
		local MissileItem = require 'zeta.script.obj.missileitem'
		return not not player:removeItem(MissileItem)
	end

	return MissileLauncher
end)()

return MissileLauncher
