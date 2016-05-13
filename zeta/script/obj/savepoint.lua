local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local Hero = require 'zeta.script.obj.hero'
local threads = require 'base.script.singleton.threads'

local SavePoint = class(Object)
SavePoint.sprite = 'savepoint'
SavePoint.solid = false

function SavePoint:playerLook(player)
	print('saving...')
	os.execute('mkdir zeta/save')

	local vec2 = require 'vec.vec2'
	local vec4 = require 'vec.vec4'
	local box2 = require 'vec.box2'
	local SpawnInfo = require 'base.script.spawninfo'

	threads:add(function()
		coroutine.yield()
		
		local function serialize(obj)
			local t = {}
			for k,v in pairs(obj) do
				if type(v) == 'table' then
					local m = getmetatable(v)
					-- hmm, explicit control of all objects ...
					if m == nil then
						v = serialize(v)
					elseif m == vec2 
					or m == vec4 
					or m == box2 
					or m == table
					then
						v = tostring(v)
					elseif Object.is(v) then 
						local objIndex = game.objs:find(v)
						if not objIndex then
							return "error('can\\'t serialize Object outside of the game')"
						end
						v = 'objs['..objIndex..']'
					elseif SpawnInfo.is(v) then
						--[[ don't save spawninfos
						local i = game.level.spawnInfos:find(v)
						if not i then
							error("can't serialize SpawnInfo outside of the game")
						end
						return 'spawnInfos['..i..']'
						--]]
						v = nil
					-- omit certain fields
					elseif Object.is(t) and ({
						playerServerObj=1,
					})[k] then
						v = nil
					else
						return "error('can\\'t serialize unknown table from key "..k.."')"
					end
				elseif type(v) == 'ctype' then
					return "error('can\\'t save ctype data!')"
				end
				t[k] = v
			end
			assert(not t.spawnType, "can't set field 'spawnType' in objects")
			if getmetatable(t) == Object then
				t.spawnType = assert(game.levelcfg.spawnTypes:find(nil, function(spawnType)
					return require(spawnType.spawn) == getmetatable(t)
				end), "failed to find spawnType for obj").spawn
			end
			return tolua(t,{indent=true})
		end
		
		file['zeta/save/save.txt'] = '{\n'
			..game.objs:map(serialize):concat(',\n')
			..'}\n'

		print('...done')
	end)
end

return SavePoint
