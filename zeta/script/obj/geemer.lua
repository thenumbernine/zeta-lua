local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local addTakesDamage = require 'zeta.script.obj.takesdamage'
local game = require 'base.script.singleton.game'

local Geemer = class(Object)
addTakesDamage(Geemer)
Geemer.sprite = 'geemer'
Geemer.solid = true
Geemer.health = 1

Geemer.attackDist = 5
Geemer.jumpVel = 10
Geemer.runVel = 7

Geemer.alertDist = 10
Geemer.nextShakeTime = -1
Geemer.shakeEndTime = -1

function Geemer:init(...)
	Geemer.super.init(self, ...)

	-- see if there's a block near us
	-- if so, stick to that block
	local level = game.level
	for side,dir in pairs(dirs) do
		local pos = self.pos + dir
		local tile = level:getTile(pos:unpack())
		if tile and tile.solid then
			self.stuckPos = pos
			self.stuckSide = side
			self.useGravity = false
			self.angle = math.deg(math.atan2(dir[2], dir[1])) + 90
			self.rotCenter = {.5, .5}
			break
		end
	end


	-- taken from thwomp code
	-- this determines the visible range below the geemer
	do
		local x, y = math.floor(self.pos[1]), math.floor(self.pos[2])
		
		repeat
			y = y - 1
			local tile = level:getTile(x,y)
			if not tile then break end
			if tile.solid then break end
		until y < 1
		y = y + 1
		self.ymin = y - 2	-- leeway?

		repeat
			y = y + 1
			local tile = level:getTile(x,y)
			if not tile then break end
			if tile.solid then break end
		until y > level.size[2]
		y = y - 1
		self.ymax = y
	end
end

function Geemer:update(dt)
	Geemer.super.update(self, dt)

	if self.onground or self.stuckPos then 
		for _,player in ipairs(game.players) do
			local delta = player.pos - self.pos
			local len = delta:length()
			-- if something made us angry
			if self.mad
			-- if the player is within their range then attack 
			or len < self.attackDist 
			-- or if the player is directl below them then attack. TODO traceline as well?
			or (math.abs(delta[1]) < 3 and player.pos[2] > self.ymin and player.pos[2] < self.ymax)
			then
				-- jump at player
				self.vel[2] = self.jumpVel
				self.vel[1] = delta[1] > 0 and self.runVel or -self.runVel
				-- if we're on a wall then don't jump into the wa
				if (self.vel[1] > 0 and self.stuckSide == 'right')
				or (self.vel[1] < 0 and self.stuckSide == 'left')
				then
					self.vel[1] = -self.vel[1]
				end

				self.angle = nil
				self.useGravity = true
				self.stuckPos = nil
				self.stuckSide = nil
			elseif len < self.alertDist then
				-- shake and let him know you're irritated
				if game.time > self.nextShakeTime then
					self.shakeEndTime = game.time + 1 + math.random()
					self.nextShakeTime = game.time + 3 + 2 * math.random()
				end
			end
		end
	end
end

local Hero = require 'zeta.script.obj.hero'
function Geemer:touch(other, side)
	if other:isa(Hero) then
		other:takeDamage(1, self, self, side)
	end
end

function Geemer:draw(...)
	local ofs = 0
	if game.time < self.shakeEndTime then
		ofs = 1/16 * math.sin(game.time * 100)
		self.pos[1] = self.pos[1] + ofs
	end
	Geemer.super.draw(self, ...)
	if game.time < self.shakeEndTime then
		self.pos[1] = self.pos[1] - ofs
	end
end

function Geemer:die()
	-- puff of smoke	
	local Puff = require 'zeta.script.obj.puff'
	Puff.puffAt(self.pos:unpack())
	-- spawn a random item
	if math.random(10) == 1 then
		local Heart = require 'zeta.script.obj.heart'
		Heart{pos=self.pos}
	end
	-- get rid of self
	self.remove = true
	-- piss off the geemers around you
	for _,other in ipairs(game.objs) do
		if other:isa(Geemer) then
			local delta = other.pos - self.pos
			if delta:length() < 2.5 then
				other.mad = true
			end
		end
	end
end

return Geemer
