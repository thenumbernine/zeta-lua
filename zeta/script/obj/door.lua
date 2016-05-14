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
	self:setState'closed'

	-- room system ...
	-- if there's a door next to this, and it's open, then open this door too
	for _,obj in ipairs(game.objs) do
		if obj ~= self
		and obj:isa(Door)
		and math.abs(obj.startPos[1] - self.startPos[1]) == 1
		and obj.startPos[2] == self.startPos[2]
		and not obj.solid
		then
			self:setState'open'
		end
	end
end

-- but if player isn't moving then pretouch won't fire ...
-- this is a common complaint ...
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
		self:setState'opening'
	end
end

Door.states = {
	opening = {
		enter = function(self)
			self.seq = 'unlock'
			self.solid = false
			self.openStartTime = game.time
			self.openEndTime = self.openStartTime + self.timeOpening
		end,
		update = function(self,dt)
			local y = (game.time - self.openStartTime) / self.timeOpening 
			self.pos[2] = self.startPos[2] + 2 * y
			if game.time >= self.openEndTime then
				self:setState'open'
			end
		end,
	},
	open = {
		enter = function(self)
			self.seq = 'unlock'
			self.solid = false
			self.closeStartTime = game.time + self.timeOpen
		end,
		update = function(self,dt)
			-- keep open
			self.pos[2] = self.startPos[2] + 2
			if game.time >= self.closeStartTime then
				self:setState'closing'
			end
		end,
	},
	closing = {
		enter = function(self)
			self.seq = 'unlock'
			self.solid = false
			self.closeEndTime = game.time + self.timeOpening
		end,
		update = function(self,dt)
			local y = 1 - (game.time - self.closeStartTime) / self.timeOpening
			self.pos[2] = self.startPos[2] + 2 * y
			if game.time >= self.closeEndTime then
				self:setState'closed'
			end
		end,
	},
	closed = {
		enter = function(self,dt)
			self.seq = 'stand'
			self.solid = true
		end,
	},
}

function Door:setState(stateName)
	local state = self.states[stateName] or error("failed to find state named "..tostring(stateName))
	if self.state and self.state.exit then self.state.exit(self) end
	self.state = state
	if self.state and self.state.enter then self.state.enter(self) end
end

function Door:update(dt)
	Door.super.update(self, dt)
	if self.state and self.state.update then self.state.update(self,dt) end
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
