local vec = require 'vec.vec2'
local Object = require 'base.script.obj.object'
local Mario = require 'mario.script.obj.mario'
local game = require 'base.script.singleton.game'
local threads = require 'base.script.singleton.threads'
local Puff = require 'mario.script.obj.puff'
local setTimeout = require 'base.script.settimeout'
local behaviors = require 'base.script.behaviors'

local Flag = behaviors(Object,
	require 'mario.script.behavior.kickable')

Flag.sprite = 'exitball'

function Flag:init(...)
	Flag.super.init(self, ...)
	
	self.resetPos = vec2(self.pos[1], self.pos[2])

	-- TODO callback to gametype
	self.heldtimes = {}
end

function Flag:update(dt)
	Flag.super.update(self, dt)
	
	-- TODO put this in the game type
	if self.heldby and not self.gameHasEnded then
		
		-- TODO callback to gametype
		local heldtime = 60
		if self.heldtimes[self.heldby] then
			heldtime = self.heldtimes[self.heldby]
		end
		
		heldtime = math.max(heldtime - dt, 0)
		if heldtime == 0 then
			-- this player won!
			-- TODO show it in the client view as an overlay 
			local winner = self.heldby
			for _,obj in ipairs(game.objs) do
				if Mario:isa(obj) then
					local gui = require 'base.script.singleton.gui'
					local showWinner = Object{pos = winner.pos}
					showWinner.solidFlags = 0
					showWinner.touchFlags = 0
					showWinner.blockFlags = 0
					showWinner.useGravity = false
					showWinner.text = 'LOSER!'
					showWinner.track = obj
					if obj == winner then showWinner.text = 'WINNER!' end
					showWinner.draw = function(self, R)
						gui.font:drawUnpacked(self.track.pos[1] - #self.text/2 + .5, self.track.pos[2]+3, 2, -2, self.text, 2, 2)
						-- gui hasn't been R-integrated yet ...
						local gl = R.gl
						gl.glEnable(gl.GL_TEXTURE_2D)
					end
				elseif Flag:isa(obj) then
					obj.gameHasEnded = true
				end
			end
			self.remove = true
			
			setTimeout(10, game.reset, game)
		end
		
		self.heldtimes[self.heldby] = heldtime
		
		self.lastHeldTime = game.time
	else
		-- after 30 seconds of not being held ... reset position (just in case)	
		if self.lastHeldTime
		and game.time - self.lastHeldTime > 30
		then
			Puff.puffAt(self.pos[1], self.pos[2])
			self.pos[1], self.pos[2] = self.resetPos[1], self.resetPos[2]
			self.lastHeldTime = nil
		end
	end
end

function Flag:draw(R, viewBBox, holdOverride)
	Flag.super.draw(self, R, viewBBox, holdOverride)
	
	if self.heldby then
		-- only render the timer once
		if not holdOverride then return end
		local heldtime = self.heldtimes[self.heldby]
		if heldtime then
			heldtime = math.floor(heldtime * 100)
			local frac = heldtime % 100
			heldtime = (heldtime - frac) / 100
			local sec = heldtime % 60
			heldtime = (heldtime - sec) / 60
			local min = heldtime
			
			local timestr = ('%.1d:%.2d:%.2d'):format(min, sec, frac)
			
			local gui = require 'base.script.singleton.gui'
			gui.font:drawUnpacked(self.heldby.pos[1]-1.5, self.heldby.pos[2]+3, 1, -1, timestr)
			-- gui hasn't been R-integrated yet ...
			local gl = R.gl	
			gl.glEnable(gl.GL_TEXTURE_2D)
		end
	end
end

return Flag
