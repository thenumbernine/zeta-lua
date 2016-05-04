local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local InvObject = require 'zeta.script.obj.invobject'
local game = require 'base.script.singleton.game'

local InvWeapon = class(InvObject)
InvWeapon.weapon = true
InvWeapon.rotCenter = {0, .5}
function InvWeapon:init(...)
	InvWeapon.super.init(self, ...)
	self.drawOffset = vec2()
end

function InvWeapon:getShotPosDir(player)
	local pos = player.pos + vec2(0, .25)
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
		if not player.onground and player.inputLeftRight == 0 and player.inputUpDown < 0 then
			dir[1] = 0
		end
	end	
	dir = dir:normalize()

	return pos, dir
end

InvWeapon.shotDelay = nil
InvWeapon.shotClass = nil
function InvWeapon:onShoot(player)
	if player.inputShootLast then return end
	player.nextShootTime = game.time + self.shotDelay

	local pos, dir = self:getShotPosDir(player)
	self.shotClass{
		shooter = player,
		pos = pos,
		dir = dir,
	}
end

function InvWeapon:drawItem(player, R, viewBBox)
	self.drawOffset = vec2(.5,0)
	if not player.ducking then
		self.drawOffset[2] = .75
	else
		self.drawOffset[2] = 0
	end

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
		or (not player.onground and player.inputLeftRight == 0 and player.inputUpDown < 0)
		then
			-- change the 45's to 90's
			self.angle = self.angle * 2
		end
	end
	
	self.drawMirror = player.drawMirror
	if self.drawMirror then self.angle = -self.angle end

	InvWeapon.super.drawItem(self, player, R, viewBBox)
end

return InvWeapon
