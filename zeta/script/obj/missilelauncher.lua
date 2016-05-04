local Missile = (function()
	local class = require 'ext.class'
	local Object = require 'base.script.obj.object'
	local game = require 'base.script.singleton.game'
	local box2 = require 'vec.box2'

	local Missile = class(Object)
	Missile.bbox = box2(-.1, 0, .1, .2)
	Missile.sprite = 'missile'
	Missile.solid = false
	Missile.useGravity = false
	Missile.speed = 50
	Missile.damage = 5
	Missile.splashDamage = 3
	Missile.rotCenter = {.5, .5}

	function Missile:init(args)
		args.vel = args.dir * self.speed	
		Missile.super.init(self, args)
	
		self.shooter = args.shooter
		self:hasBeenKicked(args.shooter)
		self:playSound('explode1')
	
		self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
	end

	local Puff = require 'zeta.script.obj.puff'
	local vec2 = require 'vec.vec2'
	function Missile:update(dt)
		Missile.super.update(self, dt)
		if self.collidesWithWorld then
			self.tick = ((self.tick or 0) + 1) % 3
			if self.tick == 0 then
				Puff{pos=self.pos + vec2(0,-.75)}
			end
		end
	end

	function Missile:pretouch(other, side)
		if not self.collidesWithWorld then return end
		if self.remove then return end
		if other == self.shooter then return true end
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
		end
		if other.takeDamgae or other.solid then
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
	
		self.sprite = 'missileblast'
		self.pos[2] = self.pos[2] - 1
		self.angle = nil

		-- TODO reset frame counter...
		self.collidesWithWorld = false
		self.colldiesWithObjects = false
		self.vel[1], self.vel[2] = 0, 0
		
		Puff.puffAt(self.pos[1], self.pos[2]+.25)
	
		self.seqStartTime = game.time
		self.removeTime = game.time + .75
	end
	
	return Missile
end)()

local MissileLauncherItem = (function()
	local class = require 'ext.class'
	local InvWeapon  = require 'zeta.script.obj.invweapon'
	
	local MissileLauncherItem = class(InvWeapon)
	MissileLauncherItem.sprite = 'missilelauncher'
	MissileLauncherItem.shotDelay = .5
	MissileLauncherItem.rotCenter = {.25,.5}
	MissileLauncherItem.shotClass = Missile 
	
	return MissileLauncherItem
end)()

return MissileLauncherItem
