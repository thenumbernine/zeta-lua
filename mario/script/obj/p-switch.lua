local game = require 'base.script.singleton.game'
local threads = require 'base.script.singleton.threads'
local Object = require 'base.script.obj.object'
local ExclaimTile = require 'mario.script.tile.exclaim'
local ExclaimOutlineTile = require 'mario.script.tile.exclaimoutline'
local teamColors = require 'base.script.teamcolors'

local PSwitch = behaviors(Object,
	require 'mario.script.behavior.kickable')

PSwitch.sprite = 'p-switch'
PSwitch.resetDuration = 1
PSwitch.floodStepDuration = .1
PSwitch.colorIndex = 1
--PSwitch.solidFlags = PSwitch.SOLID_NO

--[[
TODO add spawn params: what color does this p-switch represent?
or just have a final n bits denote that -- and of the like coin & anticoin blocks
(or don't use coin/anticoins ... use !'s and cutout blocks)
--]]

function PSwitch:init(args)
	PSwitch.super.init(self, args)
	
	-- TODO how to determine p-switch and !-block color?
	self.color = teamColors[(self.colorIndex-1) % #teamColors + 1]
end

function PSwitch:update(dt)
	PSwitch.super.update(self, dt)
	
	if self.resetTime and self.resetTime < game.time then
		if self.removable then
			self.remove = true
		else
			self.resetTime = nil
			self.seq = nil
			self.solidFlags = nil
		end
	end
end

local PushBlock = class(Object)
PushBlock.pushPriority = 2	--pushes mario
PushBlock.useGravity = false
PushBlock.sprite = 'exclaimblock'	-- make sure shader and color match too!
PushBlock.solidFlags = PushBlock.SOLID_WORLD 
PushBlock.touchFlags = 0
PushBlock.blockFlags = 0
PushBlock.bbox = box2(-.52, .52, -.02, 1.02)

function PushBlock:update(dt)
	PushBlock.super.update(self, dt)
	
	local f = (game.time - self.startTime) / self.duration
	if f < 0 then f = 0 end
	if f > 1 then f = 1 end
	local notf = 1 - f
	local x = self.srcPos[1] * notf + self.destPos[1] * f
	local y = self.srcPos[2] * notf + self.destPos[2] * f
	self:moveToPos(x, y)
end


local findTile = function(x,y)
	local tile = game.level:getTile(x,y)
	if tile then
		return ExclaimTile.is(tile)
			or ExclaimOutlineTile.is(tile)
	end
end

local flipTile = function(x,y)
	local tile = game.level:getTile(x,y)
	if tile then
		if ExclaimTile.is(tile) then
			-- TODO shaders ...
			-- on tiles nonetheless ...
			local exclaimOutlineTileType = assert(game.levelcfg.tileTypes:find(nil, function(tileType)
				return ExclaimOutlineTile.is(tileType)
			end))
			game.level:setTile(x,y, exclaimOutlineTileType, 14)
			return true
		elseif ExclaimOutlineTile.is(tile) then
			local exclaimTileType = assert(game.levelcfg.tileTypes:find(nil, function(tileType)
				return ExclaimTile.is(tileType)
			end))
			game.level:setTile(x,y, exclaimTileType, 11)
			return true
		end
	end
end

-- static function (coroutine)
function PSwitch:floodFill(cx,cy)
	coroutine.yield()

	local startTile = vec2(math.floor(cx), math.floor(cy))

	local thisTiles = table()
	thisTiles:insert(startTile)
	for _,dir in pairs(dirs) do
		thisTiles:insert(startTile + dir)
	end

	local allTiles = table()
	for _,thisTile in ipairs(thisTiles) do
		allTiles[tostring(thisTile)] = true
	end
	
	local pushblocks = table()
	local pushblockIndex


	repeat
	
		-- reset the counter here
		pushblockIndex = 0
	
		local nextTiles = table()
		for _,thisTile in ipairs(thisTiles) do
		
			local found = flipTile(unpack(thisTile))
			
			if found then
				for _,dir in pairs(dirs) do
					local nextTile = thisTile + dir
					if not allTiles[tostring(nextTile)]
					and findTile(unpack(nextTile)) then
					
						allTiles[tostring(nextTile)] = true
						nextTiles:insert(nextTile)
						

						local pushObjSrcPos = vec2(thisTile[1] + .5, thisTile[2])
						local pushObjDestPos = vec2(nextTile[1] + .5, nextTile[2])
						
						pushblockIndex = pushblockIndex + 1

						local pushblock
						if pushblockIndex <= #pushblocks then
							pushblock = pushblocks[pushblockIndex]
							pushblock:setPos(unpack(pushObjSrcPos))
						else
							pushblock = PushBlock{pos=pushObjSrcPos}
							pushblocks:insert(pushblock)
						end

						pushblock.srcPos = pushObjSrcPos
						pushblock.destPos = pushObjDestPos
						pushblock.duration = self.floodStepDuration		-- match the delay below
						pushblock.startTime = game.time
						pushblock.color = self.color
						pushblock.shader = self.shader
						pushblock.uniforms = self.uniforms
						-- TODO solid matches block's solid-ness?
					end
				end
			end
		end
		
		-- here any blocks we didn't use, remove
		for i=pushblockIndex+1,#pushblocks do
			pushblocks[i].remove = true	-- TODO fadeout or something
			pushblocks[i] = nil
		end
		
		thisTiles = nextTiles
		
		local delay = self.floodStepDuration
		local nextTime = game.time + delay
		repeat coroutine.yield() until game.time >= nextTime
	until #thisTiles == 0
end

function PSwitch:playerBounce(player)
	if self.seq ~= 'stand' then return false end

	-- TODO flood fill from current position
	threads:add(self.floodFill, self, self.pos[1], self.pos[2])
	
	self.seq = 'hit'
	self.solidFlags = 0
	self.resetTime = game.time + self.resetDuration
end

return PSwitch
