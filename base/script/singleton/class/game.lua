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

Game.viewSize = 16

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
	self.respawnThread = setTimeout(self.respawnTime, spawnInfo.respawn, spawnInfo)
end

function Game:update(dt)
	-- don't pass so many variables?
	self.deltaTime = dt
	
	-- add dt at update start instead of finish
	--  so the last update's "game.time" matches the next render's "game.time"
	self.time = self.time + dt

	self.level:update(dt)
	
	for _,obj in ipairs(self.objs) do
		obj:update(dt)
	end

--require'base.script.obj.object'.debugUpdate()

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
	obj:unlink()
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
	self.newObjs = table()	-- accumulated every frame so the objs array doesn't get manipulated while iterating 
	self.players = table()
	self.time = 0
	self.sysTime = 0

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
	self.levelInitThread = self.level:initialize()
	
	-- ... and reattach players ...
	if self.onReset then self:onReset() end	-- callback

	self:loadFromSavePoint() -- ...if we have any save data
end

Game.volume = .1

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

function Game:render(preDrawCallback)
	local glapp = require 'base.script.singleton.glapp'
	local editor = require 'base.script.singleton.editor'()
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
		if editor and editor.active then
			editor:draw(R, player.viewBBox)
		end
		
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

function Game:setSavePoint(savePoint)
	self.savePoint = savePoint
end

function Game:loadFromSavePoint()
	local save = self.savePoint
	if not save then return end

	local threads = require 'base.script.singleton.threads'

	-- NOTICE Game:respawn() uses setTimeout to create objs the next frame
	-- that would mess this up
	-- luckily zeta overrides that to do nothing
	-- (since spawn is room-driven)
	if self.respawnThread then
		-- wait for it to finish
		repeat until not threads:updateThread(self.respawnThread)
		self.respawnThread = nil
	end
	-- after loading, self:reset is called, which calls level:initialize
	--  which sandbox calls the level initFile
	-- sandbox is a thread, it's delayed one frame
	-- this means the level initFile can overwrite the loaded self state
	-- so I'll have the self keep track of it, and block the thread here
	if self.levelInitThread then
		-- wait for it to finish
		repeat until not threads:updateThread(self.levelInitThread)
		self.levelInitThread = nil
	end
	
	for k in pairs(self.objs) do
		self.objs[k] = nil
	end
	for k in pairs(self.newObjs) do
		self.newObjs[k] = nil
	end	
	for _,spawnInfo in ipairs(self.level.spawnInfos) do
		spawnInfo.obj = nil
	end
--		for k in pairs(self.players) do
--			self.players[k] = nil
--		end
	for k in pairs(self.session) do
		self.session[k] = nil
	end
	for k,v in pairs(save.session) do
		self.session[k] = v
	end
	
	self.time = save.time
	self.sysTime = save.sysTime

	local spawnObjFields = table()
	local playerObjIndex, playerServerObjIndex
	for i,saveObj in ipairs(save.objs) do
		-- copy
		-- remape spawnInfos (hope they haven't changed)
		local keystack = table{i}
		local function deserialize(srcObj, keystack)
			local obj = {}
			for k,v in pairs(srcObj) do
				if type(v) == 'table' then
					local m = getmetatable(v)
					if v.src and v.index then
						if v.src == 'game.server.playerServerObjs' then
							assert(v.index == 1)
							playerObjIndex = i
							playerServerObjIndex = v.index
							obj[k] = self.server.playerServerObjs[v.index]
						elseif v.src == 'game.objs' then
							spawnObjFields:insert(table(keystack):append{k, v.index})
						elseif v.src == 'game.level.spawnInfos' then
							local spawnInfo = self.level.spawnInfos[v.index]
							if not spawnInfo then
								print("can't find spawnInfo["..v.index.."], which means the map has probably been changed since the last save")
							else
								obj[k] = spawnInfo
								-- if we're setting an object's spawnInfo field
								-- and that object is in game.objs
								-- then set the spawnInfo's object to this
								if k == 'spawnInfo' and #keystack == 1 then
									spawnInfo.obj = obj
								end
							end
						else
							error("can't handle source array "..v.src)
						end
					else
						keystack:insert(k)
						obj[k] = setmetatable(deserialize(v, keystack), m)
						assert(k == keystack:remove())
					end
				elseif type(v) == 'function' then
					-- update upvalues within functions
					-- TODO this assumes the upvalue of 'game' is the game.  
					-- if you had: do local game = 2 obj.func = function() print(game) end end 
					--  then the upvalue would be incorrectly replaced
					-- solution? in any non-class function (like states), don't use upvalues 
					--  instead require() locally
					--  or just don't use member functions
					local j = 1
					while true do
						local n = debug.getupvalue(v, j)
						if not n then break end
						print('warning: found upvalue',n,'in key',k,'in object',i,'of type',saveObj.spawn)
						if n == 'game' then
							print('replacing "game" upvalue!')
							debug.setupvalue(v, j, self)
						end
						j = j + 1
					end
					obj[k] = v
				else
					obj[k] = v
				end
			end
			return obj
		end
		local obj = deserialize(saveObj, keystack)
		local objclass = require((assert(obj.spawn, "didn't find spawn for obj "..i)))
		setmetatable(obj, objclass)
		self.objs[i] = obj
	end

	-- use original player objs (for upvalues in anything sandboxed)
	local srcPlayer = self.objs[playerObjIndex]
	local player = self.players[1]
	for k in pairs(player) do
		player[k] = nil
	end
	for k,v in pairs(srcPlayer) do
		player[k] = v
	end
	self.objs[playerObjIndex] = player

	player.inputUp = nil
	player.inputDown = nil
	player.inputUpDown = 0
	player.inputLeft = nil
	player.inputRight = nil
	player.inputLeftRight = 0
	player.inputShoot = nil
	player.inputJump = nil
	player.inputJumpAux = nil
	player.inputShootAux = nil
	player.inputPageUp = nil
	player.inputPageDown = nil

	for _,keys in ipairs(spawnObjFields) do
		local objIndex = keys:remove()
		local dst = self.objs 
		while #keys > 1 do
			dst = dst[keys:remove(1)]
		end
		dst[keys[1]] = self.objs[objIndex]
	end

end

return Game
