local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local Hero = require 'zeta.script.obj.hero'
local threads = require 'base.script.singleton.threads'

local SavePoint = class(Object)
SavePoint.sprite = 'savepoint'
SavePoint.solid = false

SavePoint.solidFlags = 0
SavePoint.touchFlags = SavePoint.SOLID_WORLD + SavePoint.SOLID_YES
SavePoint.blockFlags = SavePoint.SOLID_WORLD

function SavePoint:playerUse(player)
	threads:add(function()
		player:popupMessage('saving...')
	end)

	os.execute('mkdir zeta/save')

	local vec2 = require 'vec.vec2'
	local vec4 = require 'vec.vec4'
	local box2 = require 'vec.box2'
	local SpawnInfo = require 'base.script.spawninfo'

	threads:add(function()
		coroutine.yield()

		-- shouldn't be any objects in waiting to attach when this runs
		-- i.e. it should run from the thread update, not the game object loop
		assert(#game.newObjs == 0)

		local function arrayNamed(v,array,arrayname,classname)
			local i = array:find(v)
			if not i then
				return "error('can\\'t serialize "..classname.." outside of the "..arrayname.."')"
			end
			--return arrayname..'['..i..']'
			return tolua{src=arrayname, index=i}
		end

		local function serialize(obj, tab)
			local lines = table()
			for k,v in pairs(obj) do
				local vstr = "error('no serialization for key: "..k.."')"
				if type(v) == 'table' then
					local m = getmetatable(v)
					-- hmm, explicit control of all objects ...
					if m == nil then
						vstr = serialize(v, tab..'\t')
					elseif m == vec2 then
						vstr = 'vec2('..table.concat(v,',')..')'
					elseif m == vec4 then
						vstr = 'vec4('..table.concat(v,',')..')'
					elseif m == box2 then
						vstr = 'box2'..tolua(v)
					elseif m == table then
						vstr = 'table'..serialize(v, tab..'\t')
					elseif Object.is(v) then 
						vstr = arrayNamed(v, game.objs, 'game.objs', 'Object')
					elseif SpawnInfo.is(v) then
						vstr = arrayNamed(v, game.level.spawnInfos, 'game.level.spawnInfos', 'SpawnInfo')
					elseif k == 'playerServerObj' then
						vstr = arrayNamed(v, game.server.playerServerObjs, 'game.server.playerServerObjs', 'PlayerServerObj')
					else
						vstr = "error('can\\'t serialize unknown table from key "..k.."')"
					end
				elseif type(v) == 'ctype' then
					vstr = "error('can\\'t save ctype data!')"
				else
					vstr = tolua(v)
				end
				local kstr = (type(k) == 'string' and k:match('^[_,a-z,A-Z][_,a-z,A-Z,0-9]*$'))
					and k or '['..tolua(k)..']'
				if vstr ~= nil then
					lines:insert(kstr..' = '..vstr)
				end
			end
			return '{\n'..lines:map(function(line)
				return tab..'\t'..line..',\n'
			end):concat()..tab..'}'
		end
		
		file['zeta/save/save.txt'] = '{\n'
			..'\tobjs={\n'
			..game.objs:map(function(obj,index)
					
					local m = getmetatable(obj)
					local _, spawntype = game.levelcfg.spawnTypes:find(nil, function(spawnType)
						return m == require(spawnType.spawn)
					end)
					if not spawntype
					and m == require 'zeta.script.obj.hero'
					then
						spawntype = {spawn='zeta.script.obj.hero'}
					end

					obj = setmetatable(table(obj),nil)
					obj.spawn = spawntype and spawntype.spawn or "error('can\\'t find spawntype')"
				
					local tab = '\t\t'
					local s = serialize(obj, tab)
					return tab..s
				end):concat(',\n')..'\n'
			..'\t},\n'
			..'\ttime='..game.time..',\n'
			..'\tsysTime='..game.sysTime..',\n'
			..'\tlevelcfg={path='..tolua(game.levelcfg.path)..'},\n'
			..'\tsession='
			..tolua(game.session,{indent=true}):split'\n':map(function(line,i)
				return (i==1 and '' or '\t')..line
			end):concat('\n')
			..',\n'
			..'}\n'
--[[
TODO serialize threads
	this means serializing functions
		who might have local references to objects ...
		see how that can get messy?
--]]
		print('...done')
	end)
end

return SavePoint
