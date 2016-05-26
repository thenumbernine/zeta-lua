local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local threads = require 'base.script.singleton.threads'
local game = require 'base.script.singleton.game'
local Hero = require 'zeta.script.obj.hero'
local vec2 = require 'vec.vec2'
local vec4 = require 'vec.vec4'

local Door = class(Object)
Door.sprite = 'door'
Door.useGravity = false
Door.pushPriority = math.huge
Door.bbox = {min={-.5,0}, max={.5,2}}

Door.timeOpening = .5
Door.timeOpen = 3
Door.blockTime = -1	-- last time the door was no longer blocked

function Door:init(...)
	Door.super.init(self, ...)
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

Door.solidFlags = Door.SOLID_WORLD
Door.touchFlags = Door.SOLID_YES	-- player, specifically
Door.blockFlags = 0
function Door:touch(other, side)
	if not other:isa(Hero) then return end
	self.blockTime = game.time + 1
	
	if not self.solid then return end
	if not other:isa(Hero) then return end

	local canOpen
	if not self.color then
		canOpen = true
	else	-- door needs a color keycard...
		local KeyCard = require 'zeta.script.obj.keycard'
		if other.items then
			for _,items in ipairs(other.items) do
				for _,item in ipairs(items) do
					if item:isa(KeyCard)
					and item.color
					and vec4.__eq(item.color, self.color)
					then
						canOpen = true
						break
					end
				end
			end
		end
	end

	if not canOpen then 
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
			self.solidFlags = 0
			self.openStartTime = game.time
			self.openEndTime = self.openStartTime + self.timeOpening
		end,
		update = function(self,dt)
			local y = math.clamp((game.time - self.openStartTime) / self.timeOpening, 0, 1)
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
			self.solidFlags = 0
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
			self.solidFlags = 0
			self.closeEndTime = game.time + self.timeOpening
		end,
		update = function(self,dt)
			local y = math.clamp(1 - (game.time - self.closeStartTime) / self.timeOpening, 0, 1)
			self.pos[2] = self.startPos[2] + 2 * y
			if game.time >= self.closeEndTime then
				self:setState'closed'
			end
		end,
	},
	closed = {
		enter = function(self,dt)
			if game.time < self.blockTime then
				self:setState'opening'
			else
				self.seq = 'stand'
				self.solid = true
				self.solidFlags = nil
			end
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

	if self.color then
		local tex = animsys:getTex('keycard', 'stand') 
		tex:bind()
		local cr,cg,cb,ca = table.unpack(self.color)
		R:quad(
			self.pos[1]-.25, self.pos[2]+1,
			.5,.5,
			0,1,
			1,-1,
			0,
			cr,cg,cb,ca)
	end
end

return Door
