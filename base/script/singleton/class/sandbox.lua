local Sandbox = class()

Sandbox.prefixCode = [[
local editor = require 'base.script.singleton.editor'
local threads = require 'base.script.singleton.threads'
local game = require 'base.script.singleton.game'
local level = game.level
local session = game.session
local player = game.players[1]
-- find object named ...
local function findObjNamed(name)
	for _,obj in ipairs(game.objs) do
		if obj.name == name then
			return obj
		end
	end
end
-- find spawn info named ...
local function findSpawnInfoNamed(name)
	for _,spawnInfo in ipairs(level.spawnInfos) do
		if spawnInfo.name == name then
			return spawnInfo
		end
	end
end
-- remove a named object
local function remove(...)
	local n = select('#', ...)
	for i=1,n do
		local name = select(i, ...)
		for _,obj in ipairs(game.objs) do
			if obj.name == name then
				obj.remove = true
			end
		end
	end
end
-- respawn a named object.  removes it if it exists
local function respawn(name, ...)
	local spawnInfo = findSpawnInfoNamed(name)
	if not spawnInfo then return end
	spawnInfo:removeObj()
	spawnInfo:respawn(...)
	return spawnInfo.obj
end
local function reloadObjClass(replaceClassName)
	xpcall(function()
		local newClass = reload(replaceClassName)
		for _,obj in ipairs(game.objs) do
			if obj.spawn == replaceClassName then
				setmetatable(obj,newClass)
			end
		end
	end, function(err)
		print(err..'\n'..debug.traceback())
	end)
end
]] 

-- argstr should be a string of ...
-- for whether 'f' is a string or a function
function Sandbox:__call(f, argstr, ...)
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
		return threads:add(function(...)
			coroutine.yield()
			xpcall(f, function(err)
				print('sandbox error while executing code')
				print(tostring(code):split'\n':map(function(line,i) return i..': '..line end):concat'\n')
				print(tostring(err))
				print(debug.traceback())
			end, ...)
		end, ...)
	end
end

return Sandbox
