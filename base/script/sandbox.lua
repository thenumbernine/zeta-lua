local class = require 'ext.class'
local Sandbox = class()

Sandbox.prefixCode = [[
local vec2 = require 'vec.vec2'
local vec4 = require 'vec.vec4'
local box2 = require 'vec.box2'
local editor = require 'base.script.singleton.editor'
local threads = require 'base.script.singleton.threads'
local game = require 'base.script.singleton.game'
local level = game.level
local session = game.session
local player = game.players[1]
-- find object named ...
local function findObjNamed(name)
	return select(2, game.objs:find(nil, function(obj)
		return obj.name == name
	end))
end
-- find spawn info named ...
local function findSpawnInfoNamed(name)
	return select(2,level.spawnInfos:find(nil, function(spawnInfo)
		return spawnInfo.name == name
	end))
end
-- respawn an object.  removes it if it exists
local function respawn(name, ...)
	local spawnInfo = findSpawnInfoNamed(name)
	if not spawnInfo then return end
	spawnInfo:removeObj()
	spawnInfo:respawn(...)
	return spawnInfo.obj
end
]] 

-- argstr should be a string of ...
-- for whether 'f' is a string or a function
function Sandbox:init(f, argstr, ...)
	-- TODO common execution for all of this?
	local code, reason
	if type(f) == 'function' then
		-- already good
	elseif type(f) == 'string' then
		code = f
		if argstr then
			code = 'local '..argstr..' = ...\n' .. code
		end
		code = self.prefixCode .. code
		f, reason = load(code)
	end
	if not f then
		-- TODO imgui popup?
		print('sandbox failed for code')
		print(tostring(code):split'\n':map(function(line,i) return i..': '..line end):concat'\n')
		print(tostring(reason))
		print(debug.traceback())
	else
		-- TODO sandbox: http://stackoverflow.com/a/6982080/2714073
		local threads = require 'base.script.singleton.threads'
		threads:add(function(...)
			coroutine.yield()
			xpcall(f, function(err)
				print('sandbox error while executing code')
				print(tostring(code):split'\n':map(function(line,i) return i..': '..line end):concat'\n')
				print(tostring(reason))
				print(debug.traceback())
			end, ...)
		end, ...)
	end
end

return Sandbox
