local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local box2 = require 'vec.box2'
local threads = require 'base.script.singleton.threads'
local game = require 'base.script.singleton.game'
local Hero = require 'zeta.script.obj.hero'
local vec2 = require 'vec.vec2'

local Door = class(Object)
Door.sprite = 'door'
Door.useGravity = false
Door.pushPriority = math.huge
Door.bbox = box2(-.5, 0, .5, 2)

Door.timeOpening = .5
Door.timeOpen = 3
Door.blockTime = 0	-- last time it was blocked

function Door:init(args)
	Door.super.init(self, args)
	self.startPos = vec2(self.pos:unpack())

	-- room system ...
	-- if there's a door next to this, and it's open, then open this door too
	for _,obj in ipairs(game.objs) do
		if obj ~= self
		and obj:isa(Door)
		and math.abs(obj.startPos[1] - self.startPos[1]) == 1
		and obj.startPos[2] == self.startPos[2]
		and not obj.solid
		then
			print('found neighbor')
			self:openDoor()
		end
	end
end

function Door:pretouch(other, side)
	if not other:isa(Hero) then return end
	self.blockTime = game.time + 1
end

local white = {1,1,1,1}
local vec4 = require 'vec.vec4'
function Door:touch(other, side)
	if not self.solid then return end
	if not other:isa(Hero) then return end

	local KeyCard = require 'zeta.script.obj.keycard'
	local hasKey = other.holding
		and other.holding:isa(KeyCard)
		and vec4.__eq(other.holding.color or white, self.color or white)
	
	if not hasKey then 
		other.pos[1] = other.lastpos[1]
		other.vel[1] = 0
		if self.pos[1] < other.pos[1] then
			other.pos[1] = other.pos[1] + .1
		else
			other.pos[1] = other.pos[1] - .1
		end
		threads:add(function()
			other:popupMessage('Security Access Level Required!')
		end)
	else
		self:openDoor()
	end
end

-- TODO turn this into a state machine, so it can start open 
function Door:openDoor()
	self.seq = 'unlock'
	self.solid = false
	threads:add(function()
		repeat
			-- open the door
			local openStartTime = game.time
			local openEndTime = openStartTime + self.timeOpening
			while game.time < openEndTime do
				coroutine.yield()
				local y = (game.time - openStartTime) / self.timeOpening 
				self.pos[2] = self.startPos[2] + 2 * y
			end
			-- keep open
			local closeStartTime = openEndTime + self.timeOpen
			while game.time < closeStartTime do
				coroutine.yield()
				self.pos[2] = self.startPos[2] + 2
			end
			-- and close
			local closeEndTime = closeStartTime + self.timeOpening
			while game.time < closeEndTime do
				coroutine.yield()
				local y = 1 - (game.time - closeStartTime) / self.timeOpening
				self.pos[2] = self.startPos[2] + 2 * y
			end
		until self.blockTime < game.time
		-- and done
		self.seq = 'stand'
		self.solid = true
	end)
end

local animsys = require 'base.script.singleton.animsys'
function Door:draw(R, viewBBox)
	local color = self.color
	self.color = nil
	Door.super.draw(self, R, viewBBox)
	self.color = color

	local tex = animsys:getTex('keycard', 'stand') 
	tex:bind()
	local cr,cg,cb,ca
	if self.color then
		cr,cg,cb,ca = table.unpack(self.color)
	else
		cr,cg,cb,ca = 1,1,1,1
	end
	R:quad(
		self.pos[1]-.25, self.pos[2]+1,
		.5,.5,
		0,1,
		1,-1,
		0,
		cr,cg,cb,ca)
end

return Door
