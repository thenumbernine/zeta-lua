local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local Item = require 'zeta.script.obj.item'
local OverlayObject = require 'base.script.item'
local game = require 'base.script.singleton.game'

local Weapon = class(Item)

Weapon.isWeapon = true
Weapon.rotCenter = {0, .5}

Weapon.shotOffset = vec2(0, .25)
function Weapon:getShotPosDir(player)
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

	return pos, dir
end

function Weapon:onUse(player)
	player.weapon = self
end

Weapon.shotDelay = nil
Weapon.shotClass = nil
function Weapon:onShoot(player)
	if player.inputShootLast and not self.rapidFire then return end
	player.nextShootTime = game.time + self.shotDelay

	local pos, dir = self:getShotPosDir(player)
	self.shotClass{
		shooter = player,
		pos = pos,
		dir = dir,
	}
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
