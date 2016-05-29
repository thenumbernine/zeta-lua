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
			return 'arrayRef{src='..('%q'):format(arrayname)..',index='..i..'}'
		end

		local function serialize(obj, tab)
			local lines = table()
			for k,v in pairs(obj) do
				local vstr = tolua(v, {
					serializeForType = table(tolua.defaultSerializeForType, {
						table = function(state, v)	--, tab, path, keyRef)
							local m = getmetatable(v)
							-- hmm, explicit control of all objects ...						
							-- [[ looks much better, but less flexible
							if m == nil then
								return serialize(v, tab..'\t')
							elseif m == vec2 then
								return 'vec2('..table.concat(v,',')..')'
							elseif m == vec4 then
								return 'vec4('..table.concat(v,',')..')'
							elseif m == box2 then
								return 'box2'..tolua(v)
							elseif m == table then
								return 'table'..serialize(v, tab..'\t')
							--]]
							--[[ the ugly way
							if m == nil
							or m == vec2
							or m == vec4
							or m == box2
							or m == table
							then
								return serialize(v, tab..'\t')
							--]]
							elseif Object.is(v) then 
								return arrayNamed(v, game.objs, 'game.objs', 'Object')
							elseif SpawnInfo.is(v) then
								return arrayNamed(v, game.level.spawnInfos, 'game.level.spawnInfos', 'SpawnInfo')
							elseif k == 'playerServerObj' then
								return arrayNamed(v, game.server.playerServerObjs, 'game.server.playerServerObjs', 'PlayerServerObj')
							else
								return "error('can\\'t serialize unknown table from key "..k.."')"
							end
						end,
						ctype = function()
							return "error('can\\'t save ctype data!')"
						end,
					}),
--[[ too all-encompassing?
					serializeMetatables = true,
					serializeMetatableFunc = function(state, m, v)
						-- elimiate all those debug metatables i set up on default types
						local mb = getmetatable(true)
						if mb ~= nil and m == mb then return 'nil' end
						local mf = getmetatable(function()end)
						if mf ~= nil and m == mf then return 'nil' end
						local mn = getmetatable(1)
						if mn ~= nil and m == mn then return 'nil' end
						local ms = getmetatable('')
						if ms ~= nil and m == ms then return 'nil' end

						-- now see if it's an object
						if type(v) == 'table' and v.spawn and m == require(v.spawn) then
							return "require '"..v.spawn.."'"
						end
						
						-- now for the ones we care about
						if m == vec2 then return 'vec2' end
						if m == vec4 then return 'vec4' end
						if m == box2 then return 'box2' end
						if m == table then return 'table' end

						return tolua.defaultSerializeMetatableFunc(state, m)
					end,
--]]
				})
				local kstr = tolua.isVarName(k) and k or '['..tolua(k)..']'
				if vstr ~= nil then
					lines:insert(kstr..' = '..vstr)
				end
			end
			return '{\n'..lines:map(function(line)
				return tab..'\t'..line..',\n'
			end):concat()..tab..'}'
		end
		
		local saveDataSerialized = '{\n'
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
		
		file['zeta/save/save.txt'] = saveDataSerialized
	
		local arrayRef = class()
		function arrayRef:init(args)
			self.index = assert(args.index)
			self.src = assert(args.src)
		end
		local code = [[
local arrayRef = ...
local table = require 'ext.table'
local vec2 = require 'vec.vec2'
local vec4 = require 'vec.vec4'
local box2 = require 'vec.box2'
return ]]..saveDataSerialized	
		local save = assert(load(code))(arrayRef)
		game:setSavePoint(save)
		
		print('...done')
	end)
end

return SavePoint
