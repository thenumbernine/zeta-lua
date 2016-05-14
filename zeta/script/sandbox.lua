-- I'm putting this in zeta because it uses zeta-specific functions
-- like popup etc

-- argstr should be a string of ...
-- for whether 'f' is a string or a function
local Sandbox = class()

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
		code = [[
local vec2 = require 'vec.vec2'
local vec4 = require 'vec.vec4'
local box2 = require 'vec.box2'
local editor = require 'base.script.singleton.editor'
local threads = require 'base.script.singleton.threads'
local game = require 'base.script.singleton.game'
local level = game.level
local session = game.session
local player = game.players[1]
]] 
-- zeta-specific
.. [[
local function popup(...) return player:popupMessage(...) end
local function centerView(...) return player:centerView(...) end
local function stopCenterView() return player:centerView() end
local function findName(name) return select(2, game.objs:find(nil, function(obj)
	return obj.spawnInfo and obj.spawnInfo.name == name
end)) end
]] .. code
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
			f(...)
		end, ...)
	end
end

return Sandbox
