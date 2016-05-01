local class = require 'ext.class'
local game = require 'base.script.singleton.game'
local animsys = require 'base.script.singleton.animsys'
local PlayerObject = require 'base.script.obj.player'
local BMObject = require 'brightmoon.script.obj.object'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'
local ffi = require 'ffi'
local glu = require 'ffi.glu'

--[[
runs a picking callback on each OpenGL pick index beneath the cursor
screenFracPos - the position on the screen
renderCallback() - the callback for rendering the scene
pickCallback(numNames, minZ, maxZ, names...) - the callback to call when a pick result is found
--]]
local selectBufferSize = 20
local selectBufferPtr = ffi.new('GLuint[?]', selectBufferSize)
local viewportBuffer = ffi.new('int[4]')
local projectionMatrixBuffer = ffi.new('float[16]')
local function glPick(screenFracPos, pickCallback)
	local R = game.R
	local gl = R.gl

	gl.glGetIntegerv(gl.GL_VIEWPORT, viewportBuffer)

	ffi.fill(selectBufferPtr, selectBufferSize, 0)	
	gl.glSelectBuffer(selectBufferSize, selectBufferPtr)
	gl.glRenderMode(gl.GL_SELECT)	
	gl.glInitNames()

	-- render() resets projection several times, so put any pre-render gl state modifiers here
	game:render(function()
		gl.glGetFloatv(gl.GL_PROJECTION_MATRIX, projectionMatrixBuffer)
		gl.glMatrixMode(gl.GL_PROJECTION)
		gl.glLoadIdentity()
		glu.gluPickMatrix(screenFracPos[1] * viewportBuffer[2], screenFracPos[2] * viewportBuffer[3],
			1/32, 1/32,
			viewportBuffer)
		gl.glMultMatrixf(projectionMatrixBuffer)
		gl.glMatrixMode(gl.GL_MODELVIEW)
	end)
	
	gl.glFlush()

	-- see if we clicked on a sprite.  dot product.  traceline to map zero plane.  stencil buffer.  feedback buffer.
	local numHits, hits
	do
		numHits = gl.glRenderMode(gl.GL_RENDER)
		hits = {}
		for i=1,selectBufferSize do
			hits[i] = selectBufferPtr[i-1]
		end
	end
	
	--[[
		# names for the Nth hit
		Nth hit min z
		Nth hit max z
		names of the Nth hit
	--]]
	
	if hits and #hits > 0 then		
		local i = 1
		local hitNo = 1
		while true do
		
			if i+2 > #hits then break end	-- make sure it at least has numNames, minZ, maxZ
			local numNames = hits[i]
			local minZ = hits[i+1]
			local maxZ = hits[i+2]
			if i+3+numNames-1 > #hits then break end	-- make sure it has the names too
			-- pass the pick callback all our pick information: #names, minZ, maxZ, and the names
			pickCallback(unpack(hits, i, i+3+numNames-1))
			i = i + 3 + numNames
		end
	end
	
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)
end


local function pickObj(screenFracPos)
	local obj
	glPick(screenFracPos, function(num, minz, maxz, uid)
		if not uid then return end
		local index = game.objs:find(nil, function(obj) return obj.uid == uid end)
		print(uid)
		if not index then return end
		obj = game.objs[index]
	end)
	return obj
end


local cursorTypes = {
	{sprite='move', offset=vec2(0,0)},
	{sprite='look', offset=vec2(-.5,-1)},
	{sprite='attack', offset=vec2(-1,0)},
}
for i,v in ipairs(cursorTypes) do
	local cursorType = cursorTypes[i]
	cursorTypes[cursorType.sprite] = cursorType
end

local Player = class(PlayerObject)

Player.speed = 300
Player.sprite = 'terra'
Player.dir = 'd'
Player.cursorTypeIndex = 1
Player.cursorSize = vec2(1,1)

function Player:init(args)
	Player.super.init(self, args)
	
	--[[
	diamond inheritence, Player -> PlayerObject, BMObject -> GameObject
	BMObject:init goes here
	--]]
	self.uid = 123	--BMObject.getNewUID()
end

function Player:update(dt)
	local gui = require 'base.script.singleton.gui'
	local mouse = gui.mouse
	
	Player.super.update(self, dt)
	
	self.mousePos[1] = self.mouseScreenPos[1] * (self.viewBBox.max[1] - self.viewBBox.min[1]) + self.viewBBox.min[1]
	self.mousePos[2] = self.mouseScreenPos[2] * (self.viewBBox.max[2] - self.viewBBox.min[2]) + self.viewBBox.min[2]
	
	self.viewPos[1] = self.viewPos[1] + .9 *  (self.pos[1] - self.viewPos[1])
	self.viewPos[2] = self.viewPos[2] + .9 *  (self.pos[2] - self.viewPos[2])
	
	-- calc mouse state so we only do change flags once
	
	self.mouseLastLeftDown = self.mouseLeftDown
	self.mouseLastRightDown = self.mouseRightDown
	self.mouseLastMiddleDown = self.mouseMiddleDown
	
	self.mouseLeftDown = mouse.leftDown
	self.mouseRightDown = mouse.rightDown
	self.mouseMiddleDown = mouse.middleDown
	
	self.mouseLeftPress = self.mouseLeftDown and not self.mouseLastLeftDown
	self.mouseRightPress = self.mouseRightDown and not self.mouseLastRightDown
	self.mouseMiddlePress = self.mouseMiddleDown and not self.mouseLastMiddleDown
	
	if self.mouseLeftPress then
		local cursorType = cursorTypes[self.cursorTypeIndex]
		if cursorType == cursorTypes.move then
			self.destPos = vec2(unpack(self.mousePos))
		elseif cursorType == cursorTypes.look then
			local obj = pickObj(self.mouseScreenPos)
			if obj and obj.inspect then obj:inspect(self) end
			
		elseif cursorType == cursorTypes.attack then
			
		end
	elseif self.mouseRightPress then
		self.cursorTypeIndex = self.cursorTypeIndex % #cursorTypes + 1
	end
	
	-- push keyboard means override last mouse click
	if self.inputLeftRight ~= 0 or self.inputUpDown ~= 0 then
		self.destPos = nil
	end

	self.vel[1] = 0
	self.vel[2] = 0
	local dx = self.inputLeftRight
	local dy = self.inputUpDown
	if self.destPos then
		dx = self.destPos[1] - self.pos[1]
		dy = self.destPos[2] - self.pos[2]
	end
	local dl2 = dx*dx + dy*dy
	if dl2 > 0 then
		local dl = math.sqrt(dl2)
		if self.destPos and dl < .1 then
			self.destPos = nil
		end
		local idl = 1 / dl
		dx = dx * idl
		dy = dy * idl

		self.vel[1] = dt * dx * self.speed
		self.vel[2] = dt * dy * self.speed
	
		local adx = math.abs(dx)
		local ady = math.abs(dy)
		if adx > ady then
			if dx < 0 then
				self.dir = 'l'
			else
				self.dir = 'r'
			end
		else
			if dy < 0 then
				self.dir = 'd'
			else
				self.dir = 'u'
			end
		end
	end
	
	local dir = self.dir
	if dir == 'r' then
		self.drawMirror = true
		dir = 'l'
	else
		self.drawMirror = false
	end
	if dx ~= 0 or dy ~= 0 then
		self.seq = 'walk'..dir
	else
		self.seq = 'stand'..dir
	end
end

function Player:draw(R, viewBBox, ...)
	local gl = R.gl
	gl.glPushName(123)	-- BMObject:draw
	
	Player.super.draw(self, R, viewBBox, ...)

	gl.glPopName()	-- BMObject:draw
	
	-- TODO no more drawing objects between tiles?
	-- how about instead we link them to a list when we find them in view bbox
	-- then we draw them later?
	if true then
		local cursorType = cursorTypes[self.cursorTypeIndex]
		local cursor = animsys:getTex('cursor', cursorType.sprite, game.time)
		cursor:bind()
		R:quad(
			self.mousePos[1] + cursorType.offset[1],
			self.mousePos[2] - cursorType.offset[2] - 1,
			self.cursorSize[1],
			self.cursorSize[2],
			0,1,1,-1,
			0,
			1,1,1,1)
		cursor:unbind()
	end
end

return Player