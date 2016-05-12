local Grenade = (function()
	local class = require 'ext.class'
	local Object = require 'base.script.obj.object'
	local game = require 'base.script.singleton.game'
	local box2 = require 'vec.box2'
	local takesDamageBehavior = require 'zeta.script.obj.takesdamage'
	local Grenade = class(takesDamageBehavior(Object))
	
	Grenade.bbox = box2(-.1, 0, .1, .2)
	Grenade.sprite = 'grenade'
	Grenade.maxHealth = 1
	Grenade.solid = true
	Grenade.damage = 3
	Grenade.splashDamage = 3
	Grenade.rotCenter = {.5, .5}

	function Grenade:init(args)
		args.vel[1] = args.vel[1] * (math.random() * .2 + .9)
		args.vel[2] = args.vel[2] * (math.random() * .2 + .9)
		Grenade.super.init(self, args)
	
		self.shooter = args.shooter
		self:hasBeenKicked(args.shooter)
	
		self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
		self.rotation = (math.random()*2-1) * 360
	
		self.detonateTime = game.time + 2.9 + math.random() * .2
	end

	local Puff = require 'zeta.script.obj.puff'
	local vec2 = require 'vec.vec2'
	function Grenade:update(dt)
		Grenade.super.update(self, dt)
		if self.collidesWithWorld then
			self.angle = self.angle + dt * self.rotation
			if game.time > self.detonateTime then
				self:blast()
			end
		end
	end
	
	function Grenade:pretouch(other, side)
		if not self.collidesWithWorld then return end
		if self.remove then return end
		if Grenade.super.pretouch(self, other, side) then return true end
-- [[ detonate on impact?
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
			self:blast(other)
			return
		end
--]]
		if other.solid then
			self:bounceOff(dirs[oppositeSide[side]])
		end
		return true
	end

	function Grenade:hit()
		self:blast()
	end

	-- TODO need normals
	function Grenade:touchTile(tile, side, plane)
		if tile and tile.solid then
			if tile.onHit then
				tile:onHit(self, side)
			end
			self:bounceOff(plane or dirs[oppositeSide[side]])
		end
	end

	Grenade.restitution = .5
	function Grenade:bounceOff(normal)
		normal = vec2(table.unpack(normal)):normalize()
		local vel = vec2(self.lastvel:unpack())
		if math.abs(vel[1]) < 1e-2 and math.abs(vel[2]) < 1e-2 then 
			self.vel[1] = 0
			self.vel[2] = 0
			self.rotation = 0
			return
		end
		local r = vel:dot(normal) * (1 + self.restitution)
		vel[1] = vel[1] - normal[1] * r 
		vel[2] = vel[2] - normal[2] * r 
		self.rotation = (math.random()*2-1) * 360
		self.vel = vel
		self.pos[1] = self.lastpos[1]
		self.pos[2] = self.lastpos[2]
		-- TODO transfer force into the object we hit?
		-- esp if it's a grenade?
	end

	function Grenade:blast(alreadyHit)
		if self.removeTime then return end
		
		-- splash damage 
		-- TODO ignore objects just hit by damage?
		local force = 10
		for _,other in ipairs(game.objs) do
			if other ~= self then
				local delta = other.pos - self.pos
				-- TODO and traceline ...
				local lenSq = delta:lenSq()
				if lenSq < 2*2 then
					if other.takeDamage and other ~= alreadyHit then
						other:takeDamage(self.splashDamage, self.shooter, self, side)
					end
					-- TODO ... only solid? (should grenades be solid?) only takeDamage (should grenades take damage?)
					if other:isa(Grenade) and other.collidesWithWorld then
						other.vel = other.vel + delta * (force / (lenSq + 1))
						other.vel[2] = other.vel[2] + 5
						other.detonateTime = math.min(other.detonateTime, game.time + math.random() * .8 + .2)
					end
				end
			end
		end
	
		self.sprite = 'missileblast'
		self.useGravity = false
		self.solid = false
		self.seqStartTime = game.time
		self.pos[2] = self.pos[2] - 1
		self.angle = nil

		self.collidesWithWorld = false
		self.colldiesWithObjects = false
		self.vel[1], self.vel[2] = 0, 0
		
		Puff.puffAt(self.pos[1], self.pos[2]+.25)
		self:playSound('explode2')
	
		self.removeTime = game.time + .75
	end
	
	return Grenade
end)()

local GrenadeLauncherItem = (function()
	local class = require 'ext.class'
	local Weapon  = require 'zeta.script.obj.weapon'
	
	local GrenadeLauncherItem = class(Weapon)
	GrenadeLauncherItem.sprite = 'grenadelauncher'
	GrenadeLauncherItem.shotDelay = .5
	GrenadeLauncherItem.shotSpeed = 18
	GrenadeLauncherItem.shotUpSpeed = 7
	GrenadeLauncherItem.shotSound = 'fire-grenade'
	GrenadeLauncherItem.rotCenter = {.25,.5}
	GrenadeLauncherItem.drawOffsetStanding = {.5, .25}
	GrenadeLauncherItem.shotClass = Grenade 
	GrenadeLauncherItem.shotOffset = {.5, .5}

	function GrenadeLauncherItem:getShotPosVel(player)
		local pos, vel = GrenadeLauncherItem.super.getShotPosVel(self, player)
		vel[2] = vel[2] + self.shotUpSpeed
		return pos, vel
	end


	--[[ cluster grenades won't work so long as grenades are solid and takesDamage themselves
	local game = require 'base.script.singleton.game'
	function GrenadeLauncherItem:onShoot(player)
		if player.inputShootLast and not self.rapidFire then return end
		player.nextShootTime = game.time + self.shotDelay

		for i=1,5 do
			local pos, dir = self:getShotPosVel(player)
			self.shotClass{
				shooter = player,
				pos = pos,
				dir = dir,
			}
		end
	end
	--]]
	
	return GrenadeLauncherItem
end)()

return GrenadeLauncherItem
