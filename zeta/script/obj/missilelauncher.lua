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

	function Missile:init(args)
		Missile.super.init(self, args)
	
		self.shooter = args.shooter
		self:hasBeenKicked(args.shooter)
	
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
		if tile and tile.solid and tile.onHit then
			tile:onHit(self, side)
		end
		self:blast()
	end

	function Missile:blast(alreadyHit)
		if self.removeTime then return end
		
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

local MissileLauncherItem = (function()
	local class = require 'ext.class'
	local Weapon  = require 'zeta.script.obj.weapon'
	
	local MissileLauncherItem = class(Weapon)
	MissileLauncherItem.sprite = 'missilelauncher'
	MissileLauncherItem.shotDelay = .5
	MissileLauncherItem.shotSpeed = 50
	MissileLauncherItem.shotSound = 'explode1'
	MissileLauncherItem.rotCenter = {.25,.5}
	MissileLauncherItem.shotClass = Missile 
	
	return MissileLauncherItem
end)()

return MissileLauncherItem
