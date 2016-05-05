local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local takesDamageBehavior = require 'zeta.script.obj.takesdamage'
local game = require 'base.script.singleton.game'

local Turret = class(takesDamageBehavior(Object))
Turret.sprite = 'turret-body'
Turret.solid = true
Turret.maxHealth = 5
Turret.rotCenter = {.5, .5}

function Turret:init(...)
	Turret.super.init(self, ...)

	-- see if there's a block near us
	-- if so, stick to that block
	local level = game.level
	for side,dir in pairs(dirs) do
		local pos = self.pos + dir
		local tile = level:getTile(pos:unpack())
		if tile and tile.solid then
			self.stuckPos = pos
			self.stuckSide = side
			self.stuckAngle = math.deg(math.atan2(dir[2], dir[1])) + 90
			self.useGravity = false
			break
		end
	end
end

function Turret:update(dt)
	Turret.super.update(self, dt)

	-- look for player
	-- shoot at player
	for _,player in ipairs(game.players) do
		local delta = player.pos - self.pos
		if delta:length() < 8 then
			self.angle = math.deg(math.atan2(delta[2], delta[1]))
			self:shootAt(player)
		end
	end
end

local BlasterShot = require 'zeta.script.obj.blaster'.shotClass
Turret.nextShootTime = -1
Turret.shotDelay = .3
function Turret:shootAt(player)
	if self.nextShootTime >= game.time then return end
	self.nextShootTime = game.time + self.shotDelay

	local dir = (player.pos - self.pos):normalize()
	BlasterShot{
		shooter = self,
		pos = self.pos,
		dir = dir,
	}
end

function Turret:draw(R, viewBBox, ...)
	-- draw base underneath
	local angle = self.angle
	self.sprite = 'turret-base'
	self.angle = self.stuckAngle
	Turret.super.draw(self, R, viewBBox, ...)
	self.sprite = nil
	self.angle = angle

	Turret.super.draw(self, R, viewBBox, ...)
end

return Turret
