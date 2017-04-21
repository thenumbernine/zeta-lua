local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'


local WalkEnemy = class(GameObject)

WalkEnemy.dir = -1
WalkEnemy.drawMirror = true	-- by default, to match initial dir
WalkEnemy.speed = 2

function WalkEnemy:init(args)
	args = table(args, {vel={self.speed * self.dir, 0}})
	WalkEnemy.super.init(self, args)
end

function WalkEnemy:update(dt)
	local level = game.level
	
	WalkEnemy.super.update(self, dt)
	
	if self.dead then return end
	
	if self.turnsAtLedge and self.onground then
		local tileUnderLeft = level:getTile(self.pos[1] + self.bbox.min[1] - level.pos[1], self.pos[2] - .5 - level.pos[2])
		if not tileUnderLeft or not tileUnderLeft.solid then
			self.dir = 1
			self.drawMirror = false
		end

		local tileUnderRight = level:getTile(self.pos[1] + self.bbox.max[1] - level.pos[1], self.pos[2] - .5 - level.pos[2])
		if not tileUnderRight or not tileUnderRight.solid then
			self.dir = -1
			self.drawMirror = true
		end
	end
	
	if self.collidedLeft then
		self.dir = 1
		self.drawMirror = false
	elseif self.collidedRight then
		self.dir = -1
		self.drawMirror = true
	end
	self.vel[1] = self.speed * self.dir
	
	for _,field in ipairs(self.touchEntHorzFields) do
		local ent = self[field]
		if ent and ent.hitByEnemy then ent:hitByEnemy(self) end
	end
end

function WalkEnemy:die(other)
	self.collidesWithObjects = false
	self.collidesWithWorld = false
	self.drawFlipped = true
	self.vel[1] = 0
	self.vel[2] = 0
	self.dead = true
	self.removeTime = game.time + 1
end

function WalkEnemy:playerBounce(other) self:die(other) end
function WalkEnemy:hitByShell(other) self:die(other) end
function WalkEnemy:hitByBlast(other) self:die(other) end

return WalkEnemy