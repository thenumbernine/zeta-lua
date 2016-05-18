local Grenade = (function()
	local class = require 'ext.class'
	local box2 = require 'vec.box2'
	local vec2 = require 'vec.vec2'
	local Object = require 'base.script.obj.object'
	local takesDamageBehavior = require 'zeta.script.obj.takesdamage'
	local MissileBlast = require 'zeta.script.obj.missileblast'
	local Puff = require 'zeta.script.obj.puff'
	local game = require 'base.script.singleton.game'
	
	local Grenade = class(takesDamageBehavior(Object))
	Grenade.bbox = box2(-.1, 0, .1, .2)
	Grenade.sprite = 'grenade'
	Grenade.maxHealth = 1
	Grenade.solid = true
	Grenade.damage = 3
	Grenade.splashDamage = 3
	Grenade.rotCenter = {.5, .5}

	function Grenade:init(...)
		Grenade.super.init(self, ...)
		
		self.vel[1] = self.vel[1] * (math.random() * .2 + .9)
		self.vel[2] = self.vel[2] * (math.random() * .2 + .9)
		self.shooter:hasKicked(self)
		self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
		self.rotation = (math.random()*2-1) * 360
		self.detonateTime = game.time + 2.9 + math.random() * .2
	end

	function Grenade:update(dt)
		Grenade.super.update(self, dt)
		if not self.onground then
			self.angle = self.angle + dt * self.rotation
		end
		if game.time > self.detonateTime then
			self:blast()
		end
	end
	
	-- TODO pass normals to touch functions?
	function Grenade:touchTile(tile, side, plane)
		if tile and tile.solid then
			if tile.onHit then
				tile:onHit(self, side)
			end
			if self:bounceOff(plane or dirs[oppositeSide[side]]) then
				self.pos[1] = self.lastpos[1]
				self.pos[2] = self.lastpos[2]
			end
		end
	end

	function Grenade:pretouch(other, side)
		if not self.collidesWithWorld then return end
		if self.remove then return end
		local Item = require 'zeta.script.obj.item'
		if other:isa(Item) then return end
		if self.kickedBy == other and self.kickHandicapTime >= game.time then
			return true
		end
-- [[ detonate on impact?
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
			self:blast(other)
			return
		end
--]]
		if other.solid then
			if self:bounceOff(dirs[oppositeSide[side]]) then
				self.pos[1] = self.lastpos[1]
				self.pos[2] = self.lastpos[2]
			end
		end
		return true
	end

	Grenade.solidFlags = Grenade.SOLID_GRENADE
	Grenade.touchFlags = Grenade.SOLID_WORLD + Grenade.SOLID_YES + Grenade.SOLID_GRENADE
	Grenade.blockFlags = Grenade.SOLID_WORLD
	
	function Grenade:touchTile_v2(tile, side, normal)
		if tile and tile.solid then
			self:bounceOff(normal)
		end
	end
	function Grenade:touch_v2(other, side)
		if self.remove then return true end
		if self.kickedBy == other and self.kickHandicapTime >= game.time then
			return true
		end
-- [[ detonate on impact?
		if other.takeDamage then
			self.detonateTime = game.time
		end
--]]
		if bit.band(other.blockFlags, other.SOLID_GRENADE) == 0 then
			return
		end
		-- bounce
		local normal = dirs[oppositeSide[side]]
		self:bounceOff(normal)
	end

	function Grenade:hit()
		self.detonateTime = math.min(self.detonateTime, game.time + math.random() * .5)
	end
	Grenade.deathSound = nil
	Grenade.removeOnDie = false
	function Grenade:die(...)
		self.detonateTime = math.min(self.detonateTime, game.time + math.random() * .5)
		-- call any onDie callbacks
		Grenade.super.die(self, ...)
	end

	Grenade.restitution = .5
	function Grenade:bounceOff(normal)
		normal = vec2(table.unpack(normal)):normalize()
		local vel = vec2(self.lastvel:unpack())
		if vel[1] == 0 and vel[2] == 0 then
			self.rotation = 0
			return
		end
		local vDotN = vel:dot(normal)
		local r = vDotN * (1 + self.restitution)
		vel[1] = vel[1] - normal[1] * r 
		vel[2] = vel[2] - normal[2] * r 
		self.rotation = (math.random()*2-1) * 360
		self.vel = vel
		-- TODO transfer force into the object we hit?
		-- esp if it's a grenade?
		return true
	end

	function Grenade:blast(alreadyHit)
		if self.remove then return end

		Puff.puffAt(self.pos[1], self.pos[2]-.5)
		MissileBlast{pos={self.pos[1], self.pos[2]-.5}}
		self:playSound('explode2')
		self.remove = true

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
	end
	
	return Grenade
end)()

local GrenadeLauncher = (function()
	local class = require 'ext.class'
	local Weapon  = require 'zeta.script.obj.weapon'

	local GrenadeLauncher = class(Weapon)
	GrenadeLauncher.sprite = 'grenadelauncher'
	GrenadeLauncher.shotDelay = .5
	GrenadeLauncher.shotSpeed = 18
	GrenadeLauncher.shotUpSpeed = 7
	GrenadeLauncher.shotSound = 'fire-grenade'
	GrenadeLauncher.rotCenter = {.25,.5}
	GrenadeLauncher.drawOffsetStanding = {.5, .25}
	GrenadeLauncher.shotClass = Grenade 
	GrenadeLauncher.shotOffset = {.5, .5}

	function GrenadeLauncher:getShotPosVel(player)
		local pos, vel = GrenadeLauncher.super.getShotPosVel(self, player)
		vel[2] = vel[2] + self.shotUpSpeed
		return pos, vel
	end

	function GrenadeLauncher:canShoot(player)
		if not GrenadeLauncher.super.canShoot(self, player) then return end	
	
		-- TODO instead of separate GrenadeItem and Grenade ...
		-- combine the two?
		-- then have ammo selection?
		local GrenadeItem = require 'zeta.script.obj.grenadeitem'

		-- TODO if player:takeItem(require'zeta.script.obj.grenadeitem') then ...
		local found
		for i=#player.items,1,-1 do
			local items = player.items[i]
			if items[1]
			and items[1]:isa(GrenadeItem)
			then
				items:remove()
				if #items == 0 then player.items:remove(i) end
				return true
			end
		end
		
		-- didn't find it
		-- TODO play out of ammo sound?
		return false
	end

	--[[ cluster grenades won't work so long as grenades are solid and takesDamage themselves
	local game = require 'base.script.singleton.game'
	function GrenadeLauncher:onShoot(player)
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
	
	return GrenadeLauncher
end)()

return GrenadeLauncher
