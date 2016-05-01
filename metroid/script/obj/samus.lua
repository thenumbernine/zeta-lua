local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local game = require 'base.script.singleton.game'
local Player = require 'base.script.obj.player'
local BeamShot = require 'metroid.script.obj.beamshot'


local Samus = class(Player)

local walkAccel = 1
local runAccel = 1
local turnAccel = 1

local walkSpeed = 12
local runSpeed = 18

local jumpSpeed = 16
local jumpTurnDrawOffsetY = .75
local jumpDuration = .5

local standBBoxHigh = 2.4
local kneelBBoxHigh = 1.8
local morphBBoxHigh = .8

local touchNGoDuration = .25

local morphBounceCondVel = 16	-- or whatever terminal vel is
local morphBounceVel = 8


Samus.sprite = 'samus'

Samus.bbox = {min={-.4, 0}, max={.4, standBBoxHigh}}
Samus.friction = math.huge

Samus.runVel = 0
Samus.jumpTime = -1

Samus.inputJumpLast = false
Samus.inputLeftRightLast = 0
Samus.inputUpDownLast = 0
Samus.inputJumpTime = -1
Samus.inputJumpThreshold = .25
Samus.inputJumpRequest = false

function Samus:init(args)
	Samus.super.init(self, args)
	print('spawning self at ',self.pos)
	self.lastvel = vec2()
end

--[[
seq = sequence to set when entering the state
nextSeq = sequence to set as nextseq when entering the state
nextState = state to set once the sequence finished.  nextSeq must be set to activate this (even if it's a meaningless sequence)
update(self) = called every frame
--]]
Samus.states = {
	stand_l = {
		seq = 'stand_l',
		enter = function(self)
			self.runVel = 0
		end,
		update = function(self)
			if not self.onground then
				self:setState('ledge_fall_l')
			else
				if self.inputLeftRight < 0 then
					self:setState('run_l')
				elseif self.inputLeftRight > 0 then
					self:setState('turn_ltor')
				elseif self.inputUpDown < 0 then
					self:setState('kneel_l')
				elseif self.inputUpDown > 0 then
					self:setState('aim_up_l')
				elseif self.inputJumpRequest then
					if self.inputLeftRight ~= 0 then
						self:setState('flip_start_l')
					else
						self:setState('jump_up_start_l')
					end
				end
			end
		end,
	},
	stand_r = {
		seq = 'stand_r',
		enter = function(self)
			self.runVel = 0
		end,
		update = function(self)
			if not self.onground then
				self:setState('ledge_fall_r')
			else
				if self.inputLeftRight > 0 then
					self:setState('run_r')
				elseif self.inputLeftRight < 0 then
					self:setState('turn_rtol')
				elseif self.inputUpDown < 0 then
					self:setState('kneel_r')
				elseif self.inputUpDown > 0 then
					self:setState('aim_up_r')
				elseif self.inputJumpRequest then
					if self.inputLeftRight ~= 0 then
						self:setState('flip_start_r')
					else
						self:setState('jump_up_start_r')
					end
				end
			end
		end,
	},
	aim_up_l = {
		seq = 'aim_up_l',
		aimDir = vec2(0,1),
		update = function(self)
			if self.inputUpDown <= 0 then
				self:setState('stand_l')
			end
			-- TODO diag as well
		end,
	},
	aim_up_r = {
		seq = 'aim_up_r',
		aimDir = vec2(0,1),
		update = function(self)
			if self.inputUpDown <= 0 then
				self:setState('stand_r')
			end
			-- TODO diag as well
		end,
	},
	run_l = {
		seq = 'run_l',
		--enter = function(self)
			--if self.runVel > 0 then self.runVel = 0 end
		--end,
		update = function(self)
			self.runVel = self.runVel - (self.inputJumpAux and runAccel or walkAccel)
			local maxSpeed = self.inputJumpAux and runSpeed or walkSpeed
			if self.runVel < -maxSpeed then self.runVel = -maxSpeed end
			self.vel[1] = self.runVel
			if not self.onground then
				self:setState('ledge_fall_l')
			else
				if self.inputLeftRight == 0 then
					self:setState('stand_l')
				elseif self.inputLeftRight > 0 then
					self:setState('turn_ltor')
				end
				if self.inputJumpRequest then
					self:setState('flip_start_l')
				end
			end
		end,
	},
	run_r = {
		seq = 'run_r',
		--enter = function(self)
			--if self.runVel < 0 then self.runVel = 0 end
		--end,
		update = function(self)
			self.runVel = self.runVel + (self.inputJumpAux and runAccel or walkAccel)
			local maxSpeed = self.inputJumpAux and runSpeed or walkSpeed
			if self.runVel > maxSpeed then self.runVel = maxSpeed end
			self.vel[1] = self.runVel
			if not self.onground then
				self:setState('ledge_fall_r')
			else
				if self.inputLeftRight == 0 then
					self:setState('stand_r')
				elseif self.inputLeftRight < 0 then
					self:setState('turn_rtol')
				end
				if self.inputJumpRequest then
					self:setState('flip_start_r')
				end
			end
		end,
	},
	run_aim_diag_down_l = {
		seq = 'run_diag_down_l',
		aimDir = vec2(-.5,-1),
		update = function(self)
			self.runVel = self.runVel - (self.inputJumpAux and runAccel or walkAccel)
			local maxSpeed = self.inputJumpAux and runSpeed or walkSpeed
			if self.runVel < -maxSpeed then self.runVel = -maxSpeed end
			self.vel[1] = self.runVel
			if not self.onground then
				self:setState('ledge_fall_l')
			else
				if self.inputLeftRight == 0 then
					self:setState('stand_l')
				elseif self.inputLeftRight > 0 then
					self:setState('turn_ltor')
				end
				if self.inputJumpRequest then
					self:setState('flip_start_l')
				end
			end
		end,
	},
	run_aim_diag_down_r = {
		seq = 'run_diag_down_r',
		aimDir = vec2(.5,-1),
		update = function(self)
			self.runVel = self.runVel + (self.inputJumpAux and runAccel or walkAccel)
			local maxSpeed = self.inputJumpAux and runSpeed or walkSpeed
			if self.runVel > maxSpeed then self.runVel = maxSpeed end
			self.vel[1] = self.runVel
			if not self.onground then
				self:setState('ledge_fall_r')
			else
				if self.inputLeftRight == 0 then
					self:setState('stand_r')
				elseif self.inputLeftRight < 0 then
					self:setState('turn_rtol')
				end
				if self.inputJumpRequest then
					self:setState('flip_start_r')
				end
			end
		end,
	},
	turn_ltor = {
		seq = 'turn_ltor',
		nextSeq = 'stand_r',
		nextState = 'stand_r',
		update = function(self)
			self.runVel = self.runVel + turnAccel
			if self.runVel > 0 then self.runVel = 0 end
			self.vel[1] = self.runVel
		end,
	},
	turn_rtol = {
		seq = 'turn_rtol',
		nextSeq = 'stand_l',
		nextState = 'stand_l',
		update = function(self)
			self.runVel = self.runVel - turnAccel
			if self.runVel < 0 then self.runVel = 0 end
			self.vel[1] = self.runVel
		end,
	},
	-- other than entrance sequence, this should be the same as jump_fall
	ledge_fall_l = {
		seq = 'ledge_fall_l',
		nextSeq = 'ledge_fall_l3',
		update = function(self)
			self.vel[1] = self.inputLeftRight * walkSpeed
			if self.onground then
				self:setState('land_l')
			elseif self.inputLeftRight > 0 then
				self:setState('ledge_fall_turn_ltor')
			end
			
		end,
	},
	ledge_fall_r = {
		seq = 'ledge_fall_r',
		nextSeq = 'ledge_fall_r3',
		update = function(self)
			self.vel[1] = self.inputLeftRight * walkSpeed
			if self.onground then
				self:setState('land_r')
			elseif self.inputLeftRight < 0 then
				self:setState('ledge_fall_turn_rtol')
			end
			
		end,
	},
	ledge_fall_turn_ltor = {
		seq = 'turn_kneel_ltor',
		nextSeq = 'kneel_r',
		nextState = 'ledge_fall_r',
		enter = function(self)
			self.runVel = 0
			self.vel[1] = 0
			self.drawOffsetY = jumpTurnDrawOffsetY
		end,
		leave = function(self)
			self.drawOffsetY = nil
		end,
	},
	ledge_fall_turn_rtol = {
		seq = 'turn_kneel_rtol',
		nextSeq = 'kneel_l',
		nextState = 'ledge_fall_l',
		enter = function(self)
			self.runVel = 0
			self.vel[1] = 0
			self.drawOffsetY = jumpTurnDrawOffsetY
		end,
		leave = function(self)
			self.drawOffsetY = nil
		end,
	},
	flip_start_l = {
		seq = 'flip_l',
		enter = function(self)
			self.vel[2] = jumpSpeed	-- do this here to lift us off ground before the next update, self.onground is checked again
			self.jumpTime = game.time
			self.inputJumpTime = -1
			self:setState('flip_l')
		end,
	},
	flip_start_r = {
		seq = 'flip_r',
		enter = function(self)
			self.vel[2] = jumpSpeed	-- do this here to lift us off ground before the next update, self.onground is checked again
			self.jumpTime = game.time
			self.inputJumpTime = -1
			self:setState('flip_r')
		end,
	},
	-- TODO introduce a variable to determine if we're jumping
	-- and use that to combine flip and flip_fall, and touchngo and touchngo_fall
	flip_l = {
		seq = 'flip_l',
		bboxHigh = kneelBBoxHigh,
		update = function(self)
			self.runVel = math.clamp(self.runVel + self.inputLeftRight * walkAccel, -walkSpeed, walkSpeed)
			self.vel[1] = self.runVel
			self.vel[2] = jumpSpeed
			
			if not self.inputJump or self.collidedUp then
				self.vel[2] = 0
				self:setState('flip_fall_l')
			elseif self.jumpTime + jumpDuration < game.time then
				self:setState('flip_fall_l')
			elseif self.onground then
				self:setState('land_l')
			elseif self.inputLeftRight > 0 and self.inputLeftRight ~= self.inputLeftRightLast then
				local tile = game.level:getTile( self.pos[1] - 1, self.pos[2])
				if tile and tile.solid then
					self:setState('touchngo_l')
				else
					self:setState('flip_r')
				end
			end
		end,
	},
	flip_r = {
		seq = 'flip_r',
		bboxHigh = kneelBBoxHigh,
		update = function(self)
			self.runVel = math.clamp(self.runVel + self.inputLeftRight * walkAccel, -walkSpeed, walkSpeed)
			self.vel[1] = self.runVel
			self.vel[2] = jumpSpeed
			
			if not self.inputJump or self.collidedUp then 
				self.vel[2] = 0
				self:setState('flip_fall_r')
			elseif self.jumpTime + jumpDuration < game.time then
				self:setState('flip_fall_r')
			elseif self.onground then
				self:setState('land_r')
			elseif self.inputLeftRight < 0 and self.inputLeftRight ~= self.inputLeftRightLast then
				local tile = game.level:getTile( self.pos[1] + 1, self.pos[2])
				if tile and tile.solid then
					self:setState('touchngo_r')
				else
					self:setState('flip_l')
				end
			end
		end,
	},
	flip_fall_l = {
		seq = 'flip_l',
		bboxHigh = kneelBBoxHigh,
		update = function(self)
			self.runVel = math.clamp(self.runVel + self.inputLeftRight * walkAccel, -walkSpeed, walkSpeed)
			self.vel[1] = self.runVel
			
			if self.onground then
				self:setState('land_l')
			elseif self.inputLeftRight > 0 and self.inputLeftRight ~= self.inputLeftRightLast then
				local tile = game.level:getTile( self.pos[1] - 1, self.pos[2])
				if tile and tile.solid then
					self:setState('touchngo_fall_l')
				else
					self:setState('flip_fall_r')
				end
			end
		end,
	},
	flip_fall_r = {
		seq = 'flip_r',
		bboxHigh = kneelBBoxHigh,
		update = function(self)
			self.runVel = math.clamp(self.runVel + self.inputLeftRight * walkAccel, -walkSpeed, walkSpeed)
			self.vel[1] = self.runVel
			
			if self.onground then
				self:setState('land_r')
			elseif self.inputLeftRight < 0 and self.inputLeftRight ~= self.inputLeftRightLast then
				local tile = game.level:getTile( self.pos[1] + 1, self.pos[2])
				if tile and tile.solid then
					self:setState('touchngo_fall_r')
				else
					self:setState('flip_fall_l')
				end
			end
		end,
	},
	touchngo_l = {
		seq = 'touchngo_l',
		update = function(self)
			self.runVel = math.clamp(self.runVel + self.inputLeftRight * walkAccel, -walkSpeed, walkSpeed)
			self.vel[1] = self.runVel
			self.vel[2] = jumpSpeed
			
			if self.inputJumpRequest then
				self.runVel = walkSpeed
				self.vel[1] = self.runVel
				self:setState('flip_start_r')
			elseif game.time - self.stateStartTime > touchNGoDuration then
				self:setState('flip_l')
			elseif self.onground then
				self:setState('land_l')
			end
		end,
	},
	touchngo_r = {
		seq = 'touchngo_r',
		update = function(self)
			self.runVel = math.clamp(self.runVel + self.inputLeftRight * walkAccel, -walkSpeed, walkSpeed)
			self.vel[1] = self.runVel
			self.vel[2] = jumpSpeed

			if self.inputJumpRequest then
				self.runVel = -walkSpeed
				self.vel[1] = self.runVel
				self:setState('flip_start_l')
			elseif game.time - self.stateStartTime > touchNGoDuration then
				self:setState('flip_r')
			elseif self.onground then
				self:setState('land_r')
			end
		end,
	},
	touchngo_fall_l = {
		seq = 'touchngo_l',
		update = function(self)
			self.runVel = math.clamp(self.runVel + self.inputLeftRight * walkAccel, -walkSpeed, walkSpeed)
			self.vel[1] = self.runVel

			if self.inputJumpRequest then
				self.runVel = walkSpeed
				self.vel[1] = self.runVel
				self:setState('flip_start_r')
			elseif game.time - self.stateStartTime > touchNGoDuration then
				self:setState('flip_fall_l')
			elseif self.onground then
				self:setState('land_l')
			end
		end,
	},
	touchngo_fall_r = {
		seq = 'touchngo_r',
		update = function(self)
			self.runVel = math.clamp(self.runVel + self.inputLeftRight * walkAccel, -walkSpeed, walkSpeed)
			self.vel[1] = self.runVel

			if self.inputJumpRequest then
				self.runVel = -walkSpeed
				self.vel[1] = self.runVel
				self:setState('flip_start_l')
			elseif game.time - self.stateStartTime > touchNGoDuration then
				self:setState('flip_fall_r')
			elseif self.onground then
				self:setState('land_r')
			end
		end,
	},
	jump_up_start_l = {
		seq = 'land_l1',
		nextSeq = 'jump_up_l',
		nextState = 'jump_up_l',
		enter = function(self)
			self.jumpTime = game.time
			self.inputJumpTime = -1
		end,
		update = function(self)
			if self.seqHasFinished then
				self.vel[2] = jumpSpeed
			end
		end,
	},
	jump_up_start_r = {
		seq = 'land_r1',
		nextSeq = 'jump_up_r',
		nextState = 'jump_up_r',
		enter = function(self)
			self.jumpTime = game.time
			self.inputJumpTime = -1
		end,
		update = function(self)
			if self.seqHasFinished then
				self.vel[2] = jumpSpeed
			end
		end,
	},
	jump_up_l = {
		seq = 'jump_up_l',
		nextSeq = 'jump_up_l2',
		update = function(self)
			self.vel[1] = self.inputLeftRight * walkSpeed
			self.vel[2] = jumpSpeed
			if not self.inputJump or self.collidedUp then
				self.vel[2] = 0
				self:setState('jump_fall_l')
			elseif self.jumpTime + jumpDuration < game.time then
				self:setState('jump_fall_l')
			elseif self.onground then
				self:setState('land_l')
			elseif self.inputLeftRight > 0 then
				self:setState('jump_up_turn_ltor')
			end
		end,
	},
	jump_up_r = {
		seq = 'jump_up_r',
		nextSeq = 'jump_up_r2',
		update = function(self)
			self.vel[1] = self.inputLeftRight * walkSpeed
			self.vel[2] = jumpSpeed
			if not self.inputJump or self.collidedUp then
				self.vel[2] = 0
				self:setState('jump_fall_r')
			elseif self.jumpTime + jumpDuration < game.time then
				self:setState('jump_fall_r')
			elseif self.onground then
				self:setState('land_r')
			elseif self.inputLeftRight < 0 then
				self:setState('jump_up_turn_rtol')
			end
		end,
	},
	jump_up_turn_ltor = {
		seq = 'turn_kneel_ltor',
		nextSeq = 'kneel_r',
		nextState = 'jump_up_r',
		enter = function(self)
			self.runVel = 0
			self.vel[1] = 0
			self.drawOffsetY = jumpTurnDrawOffsetY
		end,
		leave = function(self)
			self.drawOffsetY = nil
		end,
		update = function(self)
			self.vel[2] = jumpSpeed
		end,
	},
	jump_up_turn_rtol = {
		seq = 'turn_kneel_rtol',
		nextSeq = 'kneel_l',
		nextState = 'jump_up_l',
		enter = function(self)
			self.runVel = 0
			self.vel[1] = 0
			self.drawOffsetY = jumpTurnDrawOffsetY
		end,
		leave = function(self)
			self.drawOffsetY = nil
		end,
		update = function(self)
			self.vel[2] = jumpSpeed
		end,
	},
	jump_fall_l = {
		seq = 'jump_fall_l',
		nextSeq = 'jump_fall_l4',
		update = function(self)
			self.vel[1] = self.inputLeftRight * walkSpeed
			if self.onground then
				self:setState('land_l')
			elseif self.inputLeftRight > 0 then
				self:setState('jump_fall_turn_ltor')
			end
		end,
	},
	jump_fall_r = {
		seq = 'jump_fall_r',
		nextSeq = 'jump_fall_r4',
		update = function(self)
			self.vel[1] = self.inputLeftRight * walkSpeed
			if self.onground then
				self:setState('land_r')
			elseif self.inputLeftRight < 0 then
				self:setState('jump_fall_turn_rtol')
			end
		end,
	},
	jump_fall_turn_ltor = {
		seq = 'turn_kneel_ltor',
		nextSeq = 'kneel_l',
		nextState = 'jump_fall_r',
		enter = function(self)
			self.runVel = 0
			self.vel[1] = 0
			self.drawOffsetY = jumpTurnDrawOffsetY
		end,
		leave = function(self)
			self.drawOffsetY = nil
		end,
	},
	jump_fall_turn_rtol = {
		seq = 'turn_kneel_rtol',
		nextSeq = 'kneel_r',
		nextState = 'jump_fall_l',
		enter = function(self)
			self.runVel = 0
			self.vel[1] = 0
			self.drawOffsetY = jumpTurnDrawOffsetY
		end,
		leave = function(self)
			self.drawOffsetY = nil
		end,
	},
	land_l = {
		seq = 'land_l',
		nextSeq = 'land_l2',
		nextState = 'stand_l',
		enter = function(self)
			if self.runVel >= 0 then
				self.vel[1] = 0
				self.runVel = 0
			end
		end,
		update = function(self)
			if self.onground then 
				if self.inputLeftRight < 0 then self:setState('run_l') end
				if self.inputLeftRight > 0 then self:setState('turn_ltor') end
			end
		end,
	},
	land_r = {
		seq = 'land_r',
		nextSeq = 'land_r2',
		nextState = 'stand_r',
		enter = function(self)
			if self.runVel <= 0 then
				self.vel[1] = 0
				self.runVel = 0
			end
		end,
		update = function(self)
			if self.onground then 
				if self.inputLeftRight < 0 then self:setState('turn_rtol') end
				if self.inputLeftRight > 0 then self:setState('run_r') end
			end
		end,
	},
	--[[ kneeling ...
	press and hold down once to kneel
	then press and hold l/r to get up and keep walking while aimed down-diagonal
	
	states: walk -> kneel, run -> kneel, any sort of spinjumping & landing where there's only two blocks high -> kneel
	kneel + move in fwd dir = walking while aiming down & fwd
	--]]
	kneel_l = {
		seq = 'kneel_l',
		bboxHigh = kneelBBoxHigh,
		enter = function(self)
			self.runVel = 0
			self.vel[1] = 0
		end,
		update = function(self)
			if self.inputUpDown < 0 and self.inputUpDownLast >= 0 then
				self:setState('morph_start_l')
			elseif self.inputUpDown > 0 then
				self:setState('stand_l')
			else
				if self.inputLeftRight < 0 then
					if self.inputUpDown < 0 then
						self:setState('run_aim_diag_down_l')
					else
						self:setState('run_l')
					end
				elseif self.inputLeftRight > 0 then
					self:setState('kneel_turn_ltor')
				end
			end
		end,
	},
	kneel_r = {
		seq = 'kneel_r',
		bboxHigh = kneelBBoxHigh,
		enter = function(self)
			self.runVel = 0
			self.vel[1] = 0
		end,
		update = function(self)
			if self.inputUpDown < 0 and self.inputUpDownLast >= 0 then
				self:setState('morph_start_r')
			elseif self.inputUpDown > 0 then
				self:setState('stand_r')
			else
				if self.inputLeftRight > 0 then
					if self.inputUpDown < 0 then
						self:setState('run_aim_diag_down_r')
					else
						self:setState('run_r')
					end
				elseif self.inputLeftRight < 0 then
					self:setState('kneel_turn_rtol')
				end
			end
		end,
	},
	kneel_turn_ltor = {
		seq = 'turn_kneel_ltor',
		bboxHigh = kneelBBoxHigh,
		nextSeq = 'kneel_r',
		nextState = 'kneel_r',
	},
	kneel_turn_rtol = {
		seq = 'turn_kneel_rtol',
		bboxHigh = kneelBBoxHigh,
		nextSeq = 'kneel_l',
		nextState = 'kneel_l',
	},
	morph_start_l = {
		seq = 'enter_morph_l',
		nextSeq = 'morph_l',
		bboxHigh = morphBBoxHigh,
		nextState = 'morph_l',
	},
	morph_start_r = {
		seq = 'enter_morph_r',
		nextSeq = 'morph_r',
		bboxHigh = morphBBoxHigh,
		nextState = 'morph_r',
	},
	morph_l = {
		seq = 'morph_l',
		bboxHigh = morphBBoxHigh,
		update = function(self)
			self.vel[1] = self.inputLeftRight * walkSpeed
			if self.inputUpDown > 0 then
				self:setState('morph_end_l')
			elseif self.inputLeftRight > 0 then
				self:setState('morph_r')
			elseif self.collidedDown and self.lastvel[2] < -morphBounceCondVel then	-- TODO go by fall dist rather than pre-contact vel?
				self.vel[2] = morphBounceVel
			end
		end,
	},
	morph_r = {
		seq = 'morph_r',
		bboxHigh = morphBBoxHigh,
		update = function(self)
			self.vel[1] = self.inputLeftRight * walkSpeed
			if self.inputUpDown > 0 then
				self:setState('morph_end_r')
			elseif self.inputLeftRight < 0 then
				self:setState('morph_l')
			elseif self.collidedDown and self.lastvel[2] < -morphBounceCondVel then	-- TODO go by fall dist rather than pre-contact vel?
				self.vel[2] = morphBounceVel
			end
		end,
	},
	morph_end_l = {
		seq = 'leave_morph_l',
		nextSeq = 'kneel_l',
		bboxHigh = kneelBBoxHigh,
		nextState = 'kneel_l',
	},
	morph_end_r = {
		seq = 'leave_morph_r',
		nextSeq = 'kneel_r',
		bboxHigh = kneelBBoxHigh,
		nextState = 'kneel_r',
	},
}

Samus.state = Samus.states.stand_r
Samus.stateName = 'stand_r'

function Samus:tryToSetBBoxHigh(high)
	local blocked
	for y=0,math.ceil(high)-1 do
		local tile = game.level:getTile(self.pos[1], self.pos[2] + y)
		if tile and tile.solid then
			blocked = y
		end
	end
	if blocked then
		if blocked == 2 then	-- couldn't stand -- gotta kneel
			local facingLeft = self.stateName:sub(-2) == '_l'
			self:setState(facingLeft and 'kneel_l' or 'kneel_r')
			return true
		elseif blocked == 1 then	-- couldn't kneel -- gotta ... morph?
			local facingLeft = self.stateName:sub(-2) == '_l'
			self:setState(facingLeft and 'morph_l' or 'morph_r')
			return true
		else	-- couldn't morph ... stuck in wall?
		end
	end
	-- success!
	self.bbox.max[2] = high
end

function Samus:setState(stateName)
	local newstate = self.states[stateName]
	
	-- if we failed to set height then we bypassed the current set-state request, so return
	if self:tryToSetBBoxHigh(newstate.bboxHigh or standBBoxHigh) then return end	

	if self.state.leave then self.state.leave(self) end
	self.state = newstate
	self.stateName = stateName
	if self.state.seq then self:setSeq(self.state.seq, self.state.nextSeq) end
	self.stateStartTime = game.time
	if self.state.enter then self.state.enter(self) end
end

function Samus:update(dt)
	Samus.super.update(self, dt)

	-- should go in Player
	self.viewPos[1] = self.viewPos[1] + .9 * (self.pos[1] - self.viewPos[1])
	self.viewPos[2] = self.viewPos[2] + .9 * (self.pos[2] - self.viewPos[2])
	
	-- always look for jump button pushes
	if self.inputJump and not self.inputJumpLast then self.inputJumpTime = game.time end
	-- and then, in whichever state, look for inputJump pushes within the last time epsilon
	self.inputJumpRequest = self.inputJumpTime >= game.time - self.inputJumpThreshold

	if self.state.update then self.state.update(self) end
	if self.state.nextState and self.seqHasFinished then
		self:setState(self.state.nextState)
	end
	
	if self.inputShoot then
		if self.bbox.max[2] ~= morphBBoxHigh then
			local pos=vec2(self.pos[1], self.pos[2] + self.bbox.max[2] - 1)
			local vel
			if self.state.aimDir then
				vel = vec2(unpack(self.state.aimDir))
			else
				vel = vec2(self.stateName:sub(-2) == '_l' and -1 or 1, 0)
			end
			pos[1] = pos[1]
			vel = vel * 50
			BeamShot{
				pos=pos,
				vel=vel,
			}
		end
	end
	
	self.inputUpDownLast = self.inputUpDown
	self.inputLeftRightLast = self.inputLeftRight
	self.inputJumpLast = self.inputJump
	self.lastvel[1] = self.vel[1]
	self.lastvel[2] = self.vel[2]
end

function Samus:draw(R, viewBBox, ...)

	if self.drawOffsetY then
		self.pos[2] = self.pos[2] + self.drawOffsetY
	end

	Samus.super.draw(self, R, viewBBox, ...)
	
	if self.drawOffsetY then
		self.pos[2] = self.pos[2] - self.drawOffsetY
	end
	
-- [=[ debug info
	local text = self.stateName or ''
	text=text..'\npos '..tostring(self.pos)
	text=text..'\nvel '..tostring(self.vel)
	text=text..'\nbbox.max[2] '..tostring(self.bbox.max[2])
	text=text..'\nself.stateName:sub(-2) == "_l" '..tostring(self.stateName:sub(-2) == '_l')
	local gui = require 'base.script.singleton.gui'
	gui.font:drawUnpacked(self.pos[1]-1.5, self.pos[2], 1, -1, text)
	-- gui hasn't been R-integrated yet ...
	local gl = R.gl	
	gl.glEnable(gl.GL_TEXTURE_2D)
--]=]
end

return Samus
