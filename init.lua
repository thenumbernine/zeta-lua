#!/usr/bin/env luajit
require 'ext'
-- setup mod order  (todo store dependencies and add them accordingly?)
local modio = require 'base.script.singleton.modio'
modio.search = table{'base'}

--[[ mario
modio.search:insert(1, 'mario')
modio.levelcfg = {
	--path = 'doors',
	--path = 'fight',
	--path = 'level1',
	--path = 'lifttest',
	--path = 'mine',
	--path = 'mine2',
	--path = 'pswitch-fluids',
	path = 'pswitch-platform',	-- color profile is tweaked?
	--path = 'race',
	template = 'cave',
	music = 'music/overworld.wav',
}
--]]

--[[ metroid
modio.search:insert(1, 'metroid')
modio.levelcfg = {
	path = 'gen',
	template = 'sea',
	music = 'music/maridia.wav',
}
--]]

-- [[ zeta
modio.search:insert(1, 'zeta')
modio.levelcfg = {
	path = 'start',
	template = 'cave',
}
--]]

--[[
modio.search:insert(1, 'brightmoon')
modio.levelcfg = {
	path = 'start',
	startPositions = {{25,25}},
}
--]]

-- run main
local main = require 'base.script.main'
main()
