local class = require 'ext.class'
local table = require 'ext.table'
local audio = require 'base.script.singleton.audio'
local modio = require 'base.script.singleton.modio'
local AudioSource = require 'audio.source'

math.randomseed(os.time())

local Game = class()

Game.respawnTime = 15
Game.maxAudioDist = 30
Game.gravity = -100
Game.maxFallVel = nil	-- optional.  special case when falling down -- used for mario
Game.maxVel = 1000

-- override this with a function that returns the player's class
function Game:getPlayerClass()
	error("not implemented")
end

-- this is run upon gl init
function Game:glInit(R)
	self.R = R
	local gl = R.gl
	gl.glClearColor(0,0,0,0)
	gl.glEnable(gl.GL_BLEND)
	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)
end

Game.viewSize = 12

function Game:init()
	self:resetObjects()
	
	self.audioSources = table()
	self.audioSourceIndex = 0
	audio:setDistanceModel('linear clamped')
	for i=1,32 do	-- 31 for DirectSound, 32 for iphone, infinite for all else?
		local src = AudioSource()
		src:setReferenceDistance(self.viewSize)
		src:setMaxDistance(self.maxAudioDist)
		src:setRolloffFactor(1)
		self.audioSources[i] = src
	end
end

function Game:addObject(obj)
	self.newObjs:insert(obj)
end

function Game:setLevel(levelcfg)
	self.levelcfg = levelcfg
end

Game.startPosIndex = 0
function Game:getStartPos()
	local startPositions = self.level.spawnInfos:filter(function(spawnInfo)
		return spawnInfo.spawn == 'base.script.obj.start'
	end):map(function(spawnInfo)
		return spawnInfo.pos
	end)
	assert(#startPositions > 0, "failed to find any starting positions")
	self.startPosIndex = self.startPosIndex % #startPositions + 1
	return startPositions[self.startPosIndex] + self.level.pos
end

function Game:respawn(spawnInfo)
	setTimeout(self.respawnTime, spawnInfo.respawn, spawnInfo)
end

function Game:update(dt)
	-- add dt at update start instead of finish
	--  so the last update's "game.time" matches the next render's "game.time"
	self.time = self.time + dt

	self.level:update(dt)
	
	for _,obj in ipairs(self.objs) do
		obj:update(dt)
	end
	
		-- remove any objs
	for i=#self.objs,1,-1 do
		local obj = self.objs[i]
		
		if obj.pos[2] < -100 and obj.spawnInfo then	-- only remove it if it can respawn again
			obj.remove = true
		end
		
		if obj.remove then
			self.objs:remove(i)
			self:doRemoveObj(obj)
		end
	end

	-- add any new objects
	while #self.newObjs > 0 do
		local obj = self.newObjs:remove()
		if obj.remove then
			-- don't bother add objects if they're already to-be-removed
			-- (no single-rendered frame of existence)
			self:doRemoveObj(obj)
		else
			self.objs:insert(1, obj)
		end
	end
end

-- private?
function Game:doRemoveObj(obj)
	-- make sure it's not a player?
	local spawnInfo = obj.spawnInfo
	if spawnInfo then	-- unlink from spawnInfo 
		-- unlink obj from spawnInfo
		if spawnInfo.obj == obj then
			spawnInfo.obj = nil
		end
		-- ... and respawn?
		if self.respawnTime then
			self:respawn(spawnInfo)
		end
	end
end

function Game:resetObjects()
	self.objs = table()	-- enumeration of all active ents
	self.newObjs= table()	-- accumulated every frame so the objs array doesn't get manipulated while iterating 
	self.players = table()
	self.time = 0

	-- initialize the session variables
	-- story state, etc
	-- save and load these along with the levels
	self.session = {}
end

function Game:reset()
	-- reset objects
	self:resetObjects()
	
	-- remove old level
	if self.level then self.level.done = true end
	
	-- reload level ...
	local Level = modio:require 'script.level'
	self.level = Level(self.levelcfg)
	
	-- init spawns separate after game.level is assigned (in case they want to reference it)
	self.level:initialize()
	
	-- ... and reattach players ...
	if self.onReset then self:onReset() end	-- callback
end

function Game:getNextAudioSource()
	if #self.audioSources == 0 then return end
	local startIndex = self.audioSourceIndex
	repeat
		self.audioSourceIndex = self.audioSourceIndex % #self.audioSources + 1
		local source = self.audioSources[self.audioSourceIndex]
		if not source:isPlaying() then
			return source
		end
	until self.audioSourceIndex == startIndex
end

local box2 = require 'vec.box2'
function Game:render(preDrawCallback)
	local glapp = require 'base.script.singleton.glapp'
	local editor = require 'base.script.singleton.editor'
	local R = self.R
	local gl = R.gl
	local windowWidth, windowHeight = glapp:size()
	gl.glViewport(0, 0, windowWidth, windowHeight)
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)

	local divY = math.ceil(math.sqrt(#self.clientConn.players))
	local divX = math.ceil(#self.clientConn.players / divY)
	for playerIndex=1,#self.clientConn.players do
		local player = self.clientConn.players[playerIndex]
		local playerClientObj = self.playerClientObjs[playerIndex]
		
		local viewX = (playerIndex - 1) % divX
		local viewY = ((playerIndex - 1) - viewX) / divX
		local viewWidth = windowWidth / divX - 1		-- leave a 1-px border between views
		local viewHeight = windowHeight / divY - 1
		local aspectRatio = viewWidth / viewHeight

		gl.glViewport(viewX * windowWidth / divX, viewY * windowHeight / divY, viewWidth, viewHeight)
	
		local viewSize = self.viewSize
		R:ortho(-viewSize, viewSize, -viewSize / aspectRatio, viewSize / aspectRatio, -100, 100)
		R:viewPos(player.viewPos[1], player.viewPos[2])
		
		if preDrawCallback then preDrawCallback() end
		
		-- assuming no scaling ...
		player.viewBBox = box2(
			player.viewPos[1] - viewSize,
			player.viewPos[2] - viewSize / aspectRatio,
			player.viewPos[1] + viewSize,
			player.viewPos[2] + viewSize / aspectRatio)
		
		if self.bgtex then
			self.bgtex:bind()
			local xmin = player.viewBBox.min[1]
			local ymin = player.viewBBox.min[2]
			local xsize = 2 * aspectRatio * viewSize
			local ysize = 2 * viewSize
			R:quad(
				xmin,ymin,--xy
				xsize,ysize,--wh
				xmin/32,(ymin+ysize)/32,--txy
				xsize/32,-ysize/32,--twh
				0,--theta
				1,1,1,1
			)
		end
							
		local level = self.level
		level:draw(R, player.viewBBox)
		if editor then editor:draw(R, player.viewBBox) end
		
		-- clear draw flags
		do
			local objs = self.objs
			for i=1,#objs do
				objs[i].drawn = false
			end
		end
	
		-- draw player hud
		player:drawHUD(R, player.viewBBox)
	end
end

return Game
