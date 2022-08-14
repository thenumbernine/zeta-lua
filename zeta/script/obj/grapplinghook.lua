local class = require 'ext.class'
local GrapplingShot = (function() 
	local Object = require 'base.script.obj.object'	
	
	local GrapplingShot = class(Object)
	GrapplingShot.bbox = box2(-.4, -.4, .4, .4)
	GrapplingShot.sprite = 'blaster-shot'	-- for now ...
	GrapplingShot.rotCenter = {.5, .5}
	GrapplingShot.drawCenter = {.5, .5}
	GrapplingShot.useGravity = false

	GrapplingShot.solidFlags = GrapplingShot.SOLID_SHOT
	GrapplingShot.touchFlags = GrapplingShot.SOLID_WORLD + GrapplingShot.SOLID_YES + GrapplingShot.SOLID_NO
	GrapplingShot.blockFlags = GrapplingShot.SOLID_WORLD + GrapplingShot.SOLID_YES

	function GrapplingShot:touchTile(tileType, side, plane, x, y)
		if self.isHooked then return true end
		self:attachTo(nil)
	end

	function GrapplingShot:touch(other, side)
		if self.isHooked then return true end
		if other == self.shooter then return true end
		self:attachTo(other)
	end

	function GrapplingShot:attachTo(other)
		self.isHooked = true
		self.hookedObj = other
		self.useGravity = false
		self.solidFlags = 0
		self.touchFlags = 0
		self.blockFlags = 0
		self.vel[1] = 0 
		self.vel[2] = 0
		self.hookOffset = self.pos - (other and other.pos or {0,0})
		self.hookLength = (self.pos - self.shooter.pos):length()
	end

	GrapplingShot.Ks = 10	-- spring stiffness constant
	GrapplingShot.changeHookLengthSpeed = 5		-- blocks per second that the length changes by
	function GrapplingShot:update(dt)
		GrapplingShot.super.update(self, dt)
		
		local player = self.shooter
		
		if self.isHooked then
			self.pos[1] = self.hookOffset[1] + (self.hookedObj and self.hookedObj.pos[1] or 0)
			self.pos[2] = self.hookOffset[2] + (self.hookedObj and self.hookedObj.pos[2] or 0)
			self.vel[1] = 0
			self.vel[2] = 0
		
			-- and pull the player
			local delta = self.pos - player.pos
			local deltaLen = delta:length()
			delta = delta / deltaLen
			local s = (deltaLen - self.hookLength) * GrapplingShot.Ks * dt
			player.vel[1] = player.vel[1] + delta[1] * s
			player.vel[2] = player.vel[2] + delta[2] * s
		
			self.hookLength = self.hookLength - self.changeHookLengthSpeed * dt * player.inputUpDown
		end


		if not player.inputShoot
		and player.inputShootLast
		then
			player.hook = nil
		end
	
		if player.hook ~= self then
			self.remove = true
		end
	end

	function GrapplingShot:draw(R, viewBBox, holdOverride)
		GrapplingShot.super.draw(self, R, viewBBox, holdOverride)

		local delta = self.shooter.pos - self.pos
		local deltaLen = delta:length()
		delta = delta / deltaLen
		local drawLen = self.hookLength or deltaLen
		for i=.5,drawLen do
			R:quad(
				self.pos[1] + delta[1] * i * deltaLen / drawLen,
				self.pos[2] + delta[2] * i * deltaLen / drawLen,
				.5, .5,
				0, 0,
				1, 1,
				0,
				1,1,1,1,
				nil,
				nil,
				.5, .5)
		end
	end

	return GrapplingShot
end)()

local GrapplingHook = (function()
	local Weapon = require 'zeta.script.obj.weapon'
	local GrapplingHook = class(Weapon)
	GrapplingHook.sprite = 'blaster'
	GrapplingHook.shotDelay = .5
	GrapplingHook.shotSpeed = 35
	GrapplingHook.shotClass = GrapplingShot
	GrapplingHook.shotSound = 'shoot'
	GrapplingHook.shotOffset = vec2(0, .45)

	function GrapplingHook:doShoot(player, pos, vel)
		if player.hook then return end
		player.hook = GrapplingHook.super.doShoot(self, player, pos, vel)
	end

	return GrapplingHook
end)()

return GrapplingHook
