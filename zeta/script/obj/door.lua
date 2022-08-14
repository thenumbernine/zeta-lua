local math = require 'ext.math'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'
local Hero = require 'zeta.script.obj.hero'
local KeyCard = require 'zeta.script.obj.keycard'
local threads = require 'base.script.singleton.threads'
local game = require 'base.script.singleton.game'
local animsys = require 'base.script.singleton.animsys'
local Door = behaviors(require 'base.script.obj.object',
	require 'zeta.script.behavior.statemachine')
Door.sprite = 'door'
Door.useGravity = false
Door.pushPriority = math.huge
Door.bbox = {min={-.5,0}, max={.5,3}}
Door.timeOpening = .5
Door.timeOpen = 3
Door.blockTime = -1	-- last time the door was no longer blocked
Door.initialState = 'closed'
Door.moveDist = 3	-- same as its bbox height
Door.moveAxis = 2

function Door:init(...)
	Door.super.init(self, ...)
	self.startPos = vec2(self.pos:unpack())

	-- TODO fix th rendering too plz
	if self.angle == 90 then
		self.bbox = box2(-.5, 0, 2.5, 1)
		self.drawCenter = vec2(.5, .5)
		self.rotCenter = vec2(.5, .5 + .5/3)
		self.moveAxis = 1
	end

	-- room system ...
	-- if there's a door next to this, and it's open, then open this door too
	for _,obj in ipairs(game.objs) do
		if obj ~= self
		and Door:isa(obj)
		and math.abs(obj.startPos[1] - self.startPos[1]) == 1
		and obj.startPos[2] == self.startPos[2]
		and obj.solidFlags == 0
		then
			self:setState'open'
		end
	end
end

Door.solidFlags = Door.SOLID_WORLD
Door.touchFlags = Door.SOLID_YES	-- player, specifically
Door.blockFlags = 0
function Door:touch(other, side)
	if not Hero:isa(other) then return end
	self.blockTime = game.time + .1
	if self.solidFlags == 0 then return end

	local canOpen
	if not self.color then
		canOpen = true
	else	-- door needs a color keycard...
		if other.items then
			for _,items in ipairs(other.items) do
				for _,item in ipairs(items) do
					if KeyCard:isa(item)
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
		--[[
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
		--]]
	else
		self:setState'opening'
	end
end

Door.states = {
	opening = {
		enter = function(self)
			self.seq = 'unlock'
			self.solidFlags = 0
		end,
		update = function(self,dt)
			local y = math.clamp((game.time - self.stateStartTime) / self.timeOpening, 0, 1)
			self.pos[self.moveAxis] = self.startPos[self.moveAxis] + self.moveDist * y
			if game.time >= self.stateStartTime + self.timeOpening then
				self:setState'open'
			end
		end,
	},
	open = {
		enter = function(self)
			self.seq = 'unlock'
			self.solidFlags = 0
		end,
		update = function(self,dt)
			-- keep open
			self.pos[self.moveAxis] = self.startPos[self.moveAxis] + self.moveDist
			if game.time >= self.stateStartTime + self.timeOpen then
				self:setState'closing'
			end
		end,
	},
	closing = {
		enter = function(self)
			self.seq = 'unlock'
			self.solidFlags = 0
		end,
		update = function(self,dt)
			local y = math.clamp(1 - (game.time - self.stateStartTime) / self.timeOpening, 0, 1)
			self.pos[self.moveAxis] = self.startPos[self.moveAxis] + self.moveDist * y
			if game.time >= self.stateStartTime + self.timeOpening then
				self:setState'closed'
			end
		end,
	},
	closed = {
		enter = function(self,dt)
			if game.time < self.blockTime then
				self:setState'opening'
			else
				self.seq = nil
				self.solidFlags = nil
			end
		end,
	},
}

function Door:draw(R, viewBBox)
	local color = self.color
	self.color = nil
	Door.super.draw(self, R, viewBBox)
	self.color = color

	if self.color then
		local tex = animsys:getTex('keycard', 'stand') 
		tex:bind()
		local cr,cg,cb,ca = table.unpack(self.color)
		if self.angle == 90 then
			R:quad(
				self.pos[1]+.75, self.pos[2]+.5,
				.5,.5,
				0,1,
				1,-1,
				0,
				cr,cg,cb,ca)	
		else
			R:quad(
				self.pos[1]-.25, self.pos[2]+1,
				.5,.5,
				0,1,
				1,-1,
				0,
				cr,cg,cb,ca)
		end
	end
end

return Door
