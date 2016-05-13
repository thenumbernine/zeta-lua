local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local box2 = require 'vec.box2'
local threads = require 'base.script.singleton.threads'
local game = require 'base.script.singleton.game'

local Door = class(Object)
Door.sprite = 'door'
Door.useGravity = false
Door.pushPriority = math.huge
Door.bbox = box2(-.5, 0, .5, 2)

Door.timeOpening = .5
Door.timeOpen = 3

local white = {1,1,1,1}
local vec4 = require 'vec.vec4'
function Door:touch(other, side)
	local Hero = require 'zeta.script.obj.hero'
	if not other:isa(Hero) then return end
	if not other.items:find(nil, function(item)
		return vec4.__eq(item.color or white, self.color or white)
	end) then
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
		threads:add(function()
			-- open the door
			local openStartTime = game.time
			local openEndTime = openStartTime + self.timeOpening
			while game.time < openEndTime do
				coroutine.yield()
				local y = (game.time - openStartTime) / self.timeOpening 
				self.pos[2] = self.spawnInfo.pos[2] + 2 * y
			end
			-- keep open
			local closeStartTime = openEndTime + self.timeOpen
			while game.time < closeStartTime do
				coroutine.yield()
			end
			-- and close
			local closeEndTime = closeStartTime + self.timeOpening
			while game.time < closeEndTime do
				coroutine.yield()
				local y = 1 - (game.time - closeStartTime) / self.timeOpening
				self.pos[2] = self.spawnInfo.pos[2] + 2 * y
			end
			-- and done
		end)
	end
end

function Door:update(dt)
	Door.super.update(self, dt)
	if self.unlocked then
		self.seq = 'unlock'
	end
end

return Door
