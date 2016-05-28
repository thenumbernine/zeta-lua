local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local Item = require 'zeta.script.obj.item'
local OverlayObject = require 'base.script.item'
local game = require 'base.script.singleton.game'

local Weapon = class(Item)

Weapon.isWeapon = true
Weapon.rotCenter = {0, .5}

Weapon.shotOffset = vec2(0, .25)
Weapon.shotSpeed = nil
function Weapon:getShotPosVel(player)
	local pos = vec2(
		player.pos[1] + (player.drawMirror and -self.shotOffset[1] or self.shotOffset[1]),
		player.pos[2] + self.shotOffset[2])
	pos[2] = pos[2] + self.drawOffset[2]
	local dir = vec2()
	if player.drawMirror then
		dir[1] = -1
	else
		dir[1] = 1
	end
	if player.inputUpDown ~= 0 then
		if player.inputUpDown > 0 then
			-- if we're holding up then shoot up
			dir[2] = 1
		end
		if not (player.ducking and player.onground) then
			if player.inputUpDown < 0 then
				-- if we're holding down and jumping then shoot down
				dir[2] = -1
			end
		end
		-- if we're holding down ... but not left/right ... then duck and shoot left/right
		if player.inputLeftRight == 0 and player.inputUpDown > 0 then
			dir[1] = 0
		end
		if (not player.onground or player.climbing) and player.inputLeftRight == 0 and player.inputUpDown < 0 then
			dir[1] = 0
		end
	end	
	dir = dir:normalize()
	local vel = dir * self.shotSpeed
	return pos, vel
end

function Weapon:onUse(player)
	player.weapon = self
end

Weapon.shotClass = nil
Weapon.shotDelay = nil
Weapon.shotSound = nil
Weapon.ammo = nil
function Weapon:canShoot(player)
	if player.inputShootLast and not self.rapidFire then return end
	
	if self.ammo then
		local field = 'ammo'..self.ammo
		if player[field] < 1 then return end
		player[field] = player[field] - 1
	end

	player.nextShootTime = game.time + self.shotDelay
	return true
end

function Weapon:doShoot(player, pos, vel)
	self.shotClass{
		shooter = player,
		pos = pos,
		vel = vel, 
	}
end

function Weapon:playShotSound(player)
	if self.shotSound then
		player:playSound(self.shotSound)
	end
end

function Weapon:onShoot(player)
	if not self:canShoot(player) then return end

	self:playShotSound(player)

	local pos, vel = self:getShotPosVel(player)
	self:doShoot(player, pos, vel)
end

Weapon.drawOffsetStanding = vec2(.5, .75)
Weapon.drawOffsetDucking = vec2(.5, 0)

-- TODO - rename 'doUpdateHeldPosition' to 'updateHeldPosition'
-- and rename 'updateHeldPosition' to 'updateAndDrawOverlay'
function Weapon:doUpdateHeldPosition()
	local player = self.heldby
	self.drawOffset = player.ducking and self.drawOffsetDucking or self.drawOffsetStanding

	self.angle = 0
	if player.inputUpDown ~= 0 then
		if player.inputUpDown > 0 then
			self.angle = 45
		end
		if not (player.ducking and player.onground) then
			if player.inputUpDown < 0 then
				self.angle = -45
			end
		end
		if (player.inputLeftRight == 0 and player.inputUpDown > 0)
		or ((not player.onground or player.climbing) and player.inputLeftRight == 0 and player.inputUpDown < 0)
		then
			-- change the 45's to 90's
			self.angle = self.angle * 2
		end
	end
	
	self.drawMirror = player.drawMirror
	if self.drawMirror then self.angle = -self.angle end
end
function Weapon:updateHeldPosition(R, viewBBox)
	self:doUpdateHeldPosition()
	
	local player = self.heldby
	OverlayObject.drawItem(self, player, R, viewBBox)
end

return Weapon
