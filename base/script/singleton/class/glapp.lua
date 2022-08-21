local ffi = require 'ffi'
local bit = require 'bit'
local os = require 'ext.os'
local file = require 'ext.file'
local class = require 'ext.class'
local table = require 'ext.table'
local tolua = require 'ext.tolua'

local ImGuiApp = require 'imguiapp'
local sdl = require 'ffi.sdl'

local NetCom = require 'netrefl.netcom'

require 'netrefl.netfield_list'

local AudioSource = require 'audio.source'
local AudioBuffer = require 'audio.buffer'

local template = require 'template'
local audio = require 'base.script.singleton.audio'
local threads = require 'base.script.singleton.threads'
local game = require 'base.script.singleton.game'
local sounds = require 'base.script.singleton.sounds'
local animsys = require 'base.script.singleton.animsys'
local teamColors = require 'base.script.teamcolors'
local modio = require 'base.script.singleton.modio'

local ig = require 'imgui'


-- don't include these til after opengl init
local gui	-- ... don't include til after opengl init
local editor

local sysThisTime = 0
local sysLastTime = 0
local frameAccumTime = 0
local fixedDeltaTime = 1/50

local PlayerServerObject = class()

local PlayerClientObject = class()

function PlayerClientObject:init()
	self.effectAudioSource = AudioSource()
end

-- TODO hud here
function PlayerClientObject:drawScene(player, aspectRatio)
end

local netcom = NetCom()

netcom:addClientToServerCall{
	name='setPlayers',
	args = {
		createNetFieldList(netFieldString),
	},
	returnArgs = {
		createNetFieldList(netFieldNumber),
	},
	func = function(serverConn, playerNames)
		serverConn.server.playerServerObjs = table()
		local playerIndexes = table()
		for i=1,#playerNames do
			local playerName = playerNames[i]
			
			local playerServerObj = PlayerServerObject()
			playerServerObj.name = playerName
			playerServerObj.startIndex = playerIndex
			playerServerObj.serverConn = serverConn
			
			-- this will be the index of the playerServerObj in the server's list
			local playerIndex = #serverConn.server.playerServerObjs+1
			playerIndexes[i] = playerIndex
			
			serverConn.server.playerServerObjs:insert(playerServerObj)
		end
		serverConn.playerIndexes = playerIndexes
		return playerIndexes
	end,
	postFunc = function(clientConn, playerNames, playerIndexes)
		clientConn.playerIndexes = playerIndexes
	end,
}

local remoteGame = false
-- for remote games remoteClientConn is defined
-- for local games server is defined
-- for both game.clientConn is defined
local server, remoteClientConn


local joysticks = {}

local numPlayers = numPlayers or 1

local timescale = 1


local R
local App = class(ImGuiApp)
	-- closest resolution:
App.width = winWidth or 768
App.height = winHeight or 512
App.title = 'Zeta Engine'
App.sdlInitFlags = bit.bor(sdl.SDL_INIT_VIDEO, sdl.SDL_INIT_JOYSTICK)

function App:initGL(gl, glname)
	App.super.initGL(self, gl, glname)
	
	local Renderer = modio:require 'script.singleton.class.renderer'
	local rendererClass = Renderer.requireClasses[glname]
	if not rendererClass then error("don't have support for "..tostring(glname)) end
	R = rendererClass(gl)
	R:report('init begin')
	
	sdl.SDL_ShowCursor(sdl.SDL_DISABLE)

	sdl.SDL_JoystickEventState(sdl.SDL_ENABLE)
	for i=0,sdl.SDL_NumJoysticks()-1 do
		print('Joystick '..i..': '..ffi.string(sdl.SDL_JoystickNameForIndex(i)))
		joysticks[i] = sdl.SDL_JoystickOpen(i)
	end

	--[[
	it would be great to implicitly detect sprite sequences
	as directories (containing any pngs) in the /sprites/ folder
	from there, anything in scripts/sprites.lua would be appended
	-- but the only info needed would be the sequence data
	( and - soon - any spritesheet chopping regions for frames)
	--]]
	for _,mod in ipairs(modio.search) do
		local dirobj = file[mod..'/sprites']
		if dirobj then
			for sprite in dirobj() do
				animsys:load{name=sprite, dir=sprite}
			end
		end
	end

	for _,mod in ipairs(modio.search) do
		if os.fileexists(mod..'/script/sprites.lua') then
			local spriteTable = require(mod..'.script.sprites')
			for _,sprite in ipairs(spriteTable) do
				animsys:load(sprite)
			end
		end
	end
	
	for _,mod in ipairs(modio.search) do
		if os.fileexists(mod..'/script/sounds.lua') then
			local soundTable = require(mod..'.script.sounds')
			for _,sound in ipairs(soundTable) do
				sounds:load(sound)
			end
		end
	end
	
	local clientConn, server, remoteClientConn = netcom:start{
		port=12345,
		onConnect = function(clientConn)
			local playerNames = table()
			for i=1,numPlayers do
				playerNames:insert('Player '..i)
			end
			clientConn:netcall{'setPlayers', playerNames}
		end,
		threads = threads,
	}
	game.clientConn = clientConn
	if server then
		game.server = server
	end

	
	game:glInit(R)


	-- needs tob e done outside game atm because it modifies levelcfg ...
	-- ... which is passed to game
	local savefile = modio:find 'save/save.txt'
	
	-- TODO matches zetascript/obj/savepoint.lua ... consolidate
	local arrayRef = class()
	function arrayRef:init(args)
		self.index = assert(args.index)
		self.src = assert(args.src)
	end
	local save
	if savefile and os.fileexists(savefile) then
		local code = [[
local arrayRef = ...
local table = require 'ext.table'
return ]]..file[savefile]
		save = assert(load(code))(arrayRef)

		game:setSavePoint(save)
	end

	local levelcfg = self:loadLevelConfig(save)
	
	local tileTypes = table()
	local spawnTypes = table()
	local serializeTypes = table()
	for i=#modio.search,1,-1 do	-- start with lowest (base) first, for sequence sake
		local mod = modio.search[i]
		if os.fileexists(mod..'/script/tiletypes.lua') then
			tileTypes:append(require(mod..'.script.tiletypes'))
		end
		if os.fileexists(mod..'/script/spawntypes.lua') then
			local modSpawnTypes = require(mod..'.script.spawntypes')
			spawnTypes:append(modSpawnTypes.spawn)
			serializeTypes:append(modSpawnTypes.spawn)
			serializeTypes:append(modSpawnTypes.serialize)
		end
	end
	-- now normalize all planes
	-- either here or in Game:setLevel()
	-- notice this currently modifies the original tileType objects ...
	for _,tileType in ipairs(tileTypes) do
		local p = tileType.plane
		if p then
			local len = math.sqrt(p[1]*p[1] + p[2]*p[2] + p[3]*p[3])
			p[1] = p[1] / len
			p[2] = p[2] / len
			p[3] = p[3] / len
		end
	end
	levelcfg.tileTypes = tileTypes
	levelcfg.spawnTypes = spawnTypes
	levelcfg.serializeTypes = serializeTypes

	game:setLevel(levelcfg)
	
	
	game.playerClientObjs = table()
	game.onReset = function()
		if server then
			for _,playerServerObj in ipairs(server.playerServerObjs) do
				local playerClass = game:getPlayerClass()
				local player = playerClass{
					name = playerName,
					pos = game:getStartPos(),
					color = teamColors[#game.players % #teamColors + 1],
				}
				game.players:insert(player)
				playerServerObj.player = player
				player.playerServerObj = playerServerObj
			end
		end
		
		-- TODO send client a command to do this
		game.clientConn.players = table()
		for i=1,#game.clientConn.playerIndexes do
			local playerIndex = game.clientConn.playerIndexes[i]
			local player = game.players[playerIndex]
			game.playerClientObjs[i] = PlayerClientObject()
			game.playerClientObjs[i].player = player
			game.clientConn.players:insert(player)	-- TODO should be playerClientObjs[i] ... or just don't use clientConn.players
		end
	end


	game:reset()


	netcom:addObject{name='game', object=game}
	
	-- don't include this til after opengl is initialized
	gui = require 'base.script.singleton.gui'
	editor = require 'base.script.singleton.editor'()
	if editor then editor:setTileKeys(tilekeys) end

	if levelcfg.music then
		local bgMusicFileName = modio:find(levelcfg.music)
		if bgMusicFileName then
			self.bgMusic = AudioBuffer(bgMusicFileName)	-- TODO specify by mod init or something
			self.bgAudioSource = AudioSource()
			self.bgAudioSource:setBuffer(self.bgMusic)
			self.bgAudioSource:setLooping(true)
			self.bgAudioSource:setGain(game.audioConfig.backgroundVolume)
			self.bgAudioSource:play()
		end
	end
	
	R:report('init end')
end

function App:loadLevelConfig(save)
	-- set load level info
		-- first get it from the modio
	local levelcfg =
		(save and save.levelcfg)
		or modio.levelcfg
		or (os.fileexists'levelcfg.lua' and assert(load('return '..file['levelcfg.lua']))())
	assert(levelcfg, "failed to find levelcfg info in save file, modio, or levelcfg.lua file")
	return levelcfg
end

local inputKeyNames = table{
	'Up',
	'Down',
	'Left',
	'Right',
	'Jump',
	'JumpAux',
	'Shoot',
	'ShootAux',
	'PageUp',
	'PageDown',
	'Pause',
}

local configFileName = 'config'
local config
if os.fileexists(configFileName) then
	config = assert(load('return '..file[configFileName]))()
end
if type(config) ~= 'table' then config = {} end
if type(config.playerKeys) ~= 'table' then
	config.playerKeys = {}
end
for i=#config.playerKeys+1,numPlayers do
	config.playerKeys[i] = {}
end


local modalsOpened = {
	main = false,
	-- TODO don't do this?  merge with modal system somehow?
	controls = false,

	audio = false,
	playerInput = require 'ext.range'(numPlayers):mapi(function() return false end),
}

-- TODO could this be combined with the menus into a menu stack?  more organized than all these separate bools?
local waitingForEvent

function getEventName(event, a,b,c)
	local function dir(d)
		local s = table()
		local ds = 'udlr'
		for i=1,4 do
			if 0 ~= bit.band(d,bit.lshift(1,i-1)) then
				s:insert(ds:sub(i,i))
			end
		end
		return s:concat()
	end
	local function key(k)
		return a	--string.char(k)
	end
	return template(({
		[sdl.SDL_JOYHATMOTION] = 'joy<?=a?> hat<?=b?> <?=dir(c)?>',
		[sdl.SDL_JOYAXISMOTION] = 'joy<?=a?> axis<?=b?> <?=c?>',
		[sdl.SDL_JOYBUTTONDOWN] = 'joy<?=a?> button<?=b?>',
		[sdl.SDL_KEYDOWN] = 'key<?=key(a)?>',
	})[event], {
		a=a, b=b, c=c,
		dir=dir, key=key,
	})
end

-- not a SDL event
local function processEvent(press, ...)
	if waitingForEvent then
		if press then
			local ev = {...}
			ev.name = getEventName(...)
			-- give the event a name
--print('got', ev.name)
			waitingForEvent.callback(ev)
			waitingForEvent = nil
		end
	else
		local descLen = select('#', ...)
		for playerIndex, playerConfig in ipairs(config.playerKeys) do
			for buttonName, buttonDesc in pairs(playerConfig) do
				if descLen == #buttonDesc then
					local match = true
					for i=1,descLen do
						if select(i, ...) ~= buttonDesc[i] then
							match = false
							break
						end
					end
					if match then
						local player = game.players[playerIndex]
						if player then
							player['input'..buttonName] = press
						end
					end
				end
			end
		end
	end
end


function App:event(event, ...)
	App.super.event(self, event, ...)
	
	if editor then
		if editor:event(event) then return end
	end

	if editor and editor.active and editor.isHandlingKeyboard then return end

	if event.type == sdl.SDL_JOYHATMOTION then
		--if event.jhat.value ~= 0 then
			-- TODO make sure all hat value bits are cleared
			-- or keep track of press/release
			for i=0,3 do
				local dirbit = bit.lshift(1,i)
				local press = bit.band(dirbit, event.jhat.value) ~= 0
				processEvent(press, sdl.SDL_JOYHATMOTION, event.jhat.which, event.jhat.hat, dirbit)
			end
			--[[
			if event.jhat.value == sdl.SDL_HAT_CENTERED then
				for i=0,3 do
					local dirbit = bit.lshift(1,i)
					processEvent(false, sdl.SDL_JOYHATMOTION, event.jhat.which, event.jhat.hat, dirbit)
				end
			end
			--]]
		--end
	elseif event.type == sdl.SDL_JOYAXISMOTION then
		-- -1,0,1 depend on the axis press
		local lr = math.floor(3 * (tonumber(event.jaxis.value) + 32768) / 65536) - 1
		local press = lr ~= 0
		if not press then
			-- clear both left and right movement
			processEvent(press, sdl.SDL_JOYAXISMOTION, event.jaxis.which, event.jaxis.axis, -1)
			processEvent(press, sdl.SDL_JOYAXISMOTION, event.jaxis.which, event.jaxis.axis, 1)
		else
			-- set movement for the lr direction
			processEvent(press, sdl.SDL_JOYAXISMOTION, event.jaxis.which, event.jaxis.axis, lr)
		end
	elseif event.type == sdl.SDL_JOYBUTTONDOWN or event.type == sdl.SDL_JOYBUTTONUP then
		-- event.jbutton.state is 0/1 for up/down, right?
		local press = event.type == sdl.SDL_JOYBUTTONDOWN
		processEvent(press, sdl.SDL_JOYBUTTONDOWN, event.jbutton.which, event.jbutton.button)
	elseif event.type == sdl.SDL_KEYDOWN or event.type == sdl.SDL_KEYUP then
		local press = event.type == sdl.SDL_KEYDOWN
		processEvent(press, sdl.SDL_KEYDOWN, event.key.keysym.sym)
	-- else mouse buttons?
	-- else mouse motion / position?
	end
	
	if event.type == sdl.SDL_MOUSEMOTION then
		local player = game.clientConn.players[1]
		local wx, wy = self:size()
		player.mouseScreenPos[1] = event.button.x / wx
		player.mouseScreenPos[2] = 1 - event.button.y / wy
	end

	--[[ slowdown effect
	if event.key.keysym.sym == sdl.SDLK_BACKQUOTE then
		timescale = 1 - 4/5 * (press and 1 or 0)
	end
	--]]

	if event.type == sdl.SDL_KEYDOWN then
		if event.key.keysym.sym == sdl.SDLK_ESCAPE then
			-- TODO better system? 
			if modalsOpened.controls then
				modalsOpened.controls = false
			elseif modalsOpened.audio then
				modalsOpened.audio = false
			else
				modalsOpened.main = not modalsOpened.main
			end
		elseif event.key.keysym.sym == sdl.SDLK_F2 then
			game:reset()
		end
	end
end
	
local fpsTime = 0
local fpsFrames = 0
function App:update(...)
	R:report('update begin')

	for _,player in ipairs(game.players) do
		local x = 0
		if player.inputUp then x=x+1 end
		if player.inputDown then x=x-1 end
		player.inputUpDown = x
		
		local x = 0
		if player.inputLeft then x=x-1 end
		if player.inputRight then x=x+1 end
		player.inputLeftRight = x
	
		-- has to be done here, because game.pause keeps the player loop from updating
		if player.inputPause and not player.inputPauseLast then
			game.paused = not game.paused
		end
		player.inputPauseLast = player.inputPause
	end

	--[[ show fps
	fpsFrames = fpsFrames + 1
	if sysThisTime - fpsTime > 1 then
		io.write('fps: '..(fpsFrames / (sysThisTime - fpsTime)))
		fpsTime = sysThisTime
		fpsFrames = 0
		-- [=[ show # objs
		local tileCount = 0
		for x,col in pairs(game.level.objsAtTile) do
			for y,tile in pairs(col) do
				tileCount = tileCount + 1
			end
		end
		io.write(' tiles: '..tileCount)
		--]=]
		io.write('\n')
		io.stdout:flush()
	end
	--]]

	-- don't use these.  they're based on the sdl time.
	sysLastTime = sysThisTime
	sysThisTime = sdl.SDL_GetTicks() / 1000
	local sysDeltaTime = sysThisTime - sysLastTime

	-- use these. they're based on the game time, updated at the sdl clock rate.
	game.sysDeltaTime = sysDeltaTime
	game.sysLastTime = game.sysTime
	game.sysTime = game.sysTime + sysDeltaTime

	if not (game.paused or modalsOpened.main) then
	--if sysThisTime > 5 then
	
		frameAccumTime = frameAccumTime + sysDeltaTime
		if frameAccumTime >= fixedDeltaTime then
	
			-- TODO gather input here ... or in event()
			
			-- update
			local skips = -1
			while frameAccumTime >= fixedDeltaTime do
				skips = skips + 1
				frameAccumTime = frameAccumTime - fixedDeltaTime
				
				-- and update the game!
				game:update(fixedDeltaTime * timescale)

				R:report('game:update')
			end
			--if skips > 0 then print(skips,'skips') end
		end
	end

	game:render()
	R:report('game:render')
	
	if editor then editor:update() end
	gui:update()
	threads:update()
	
	App.super.update(self, ...)
	
	R:report('update end')
end

local function modalBegin(title, t, k)
	return ig.luatableBegin(title, t, k, bit.bor(
			ig.ImGuiWindowFlags_NoTitleBar,
			ig.ImGuiWindowFlags_NoResize,
			ig.ImGuiWindowFlags_NoCollapse,
			ig.ImGuiWindowFlags_AlwaysAutoResize,
			ig.ImGuiWindowFlags_Modal,
		0))
end


function App:updateGUI(...)
	editor:updateGUI(...)
	
	if modalsOpened.main then
		modalBegin('Main', modalsOpened, 'main')
		if ig.igButton'Controls...' then
			modalsOpened.controls = true
		end
		if ig.igButton'Audio...' then
			modalsOpened.audio = true
		end
		if ig.igButton'Return To Game' then
			modalsOpened.main = false
		end
		if ig.igButton'Quit' then
			self:requestExit()
		end
		ig.igEnd()

		if modalsOpened.controls then
			modalBegin('Controls', nil)
			for playerIndex=1,numPlayers do
				if ig.igButton('Player '..playerIndex) then
					modalsOpened.playerInput[playerIndex] = true
				end
			end
			if ig.igButton'Done' then
				modalsOpened.controls = false
			end
			ig.igEnd()
		end

		if modalsOpened.audio then
			modalBegin('Audio', nil)
				if ig.luatableSliderFloat('fx volume', game.audioConfig, 'effectVolume', 0, 1) then
					--[[ if you want, update all previous audio sources...
					for _,src in ipairs(game.audioSources) do
						-- TODO if the gameplay sets the gain down then we'll want to multiply by their default gain
						src:setGain(audioConfig.effectVolume * src.gain)
					end
					--]]
				end
				if ig.luatableSliderFloat('bg volume', game.audioConfig, 'backgroundVolume', 0, 1) then
					self.bgAudioSource:setGain(game.audioConfig.backgroundVolume)
				end
				if ig.igButton'Done' then
					modalsOpened.audio = false
				end
			ig.igEnd()
		end

		for playerIndex=1,numPlayers do
			if modalsOpened.playerInput[playerIndex] then
				modalBegin('Player '..playerIndex..' Input', modalsOpened.playerInput, playerIndex)
					
					local thread
					if ig.igButton'Set All' then
						thread = coroutine.create(function()
							for _,inputKeyName in ipairs(inputKeyNames) do
								waitingForEvent = {
									key = inputKeyName,
									playerIndex = playerIndex,
									callback = function(ev)
										config.playerKeys[playerIndex][inputKeyName] = ev
										file[configFileName] = tolua(config, {indent=true})
										-- next resume
										threads:add(function()
											coroutine.yield()
											coroutine.resume(thread)
										end)
									end,
								}
									-- wait til next resume
								coroutine.yield()
							end
						end)
						coroutine.resume(thread)
					end
					for _,inputKeyName in ipairs(inputKeyNames) do
						ig.igText(inputKeyName)
						ig.igSameLine()
						local ev = config.playerKeys[playerIndex][inputKeyName]
						if ig.igButton(
							waitingForEvent
							and waitingForEvent.key == inputKeyName
							and waitingForEvent.playerIndex == playerIndex
							and 'Press Button...' or (ev and ev.name) or '?')
						then
							waitingForEvent = {
								key = inputKeyName,
								playerIndex = playerIndex,
								callback = function(ev)
									config.playerKeys[playerIndex][inputKeyName] = ev
									file[configFileName] = tolua(config, {indent=true})
								end,
							}
						end
					end
					if ig.igButton'Done' then
						modalsOpened.playerInput[playerIndex] = false
					end
				ig.igEnd()
			end
		end
	end
end

function App:exit()
	audio:shutdown()
	App.super.exit(self)
end

return App
