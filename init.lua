#!/usr/bin/env luajit

-- setup global env:
ffi = require 'ffi'
bit = require 'bit'
require 'ext'
require 'vec'


--[[
cmdline args for tweaking the environment / packages to get things working
--]]
for i=1,select('#',...) do
	local arg = select(i,...)

	-- override audio system 
	-- see audio/currentsystem.lua for valid options
	local audio = arg:match('^audio=(.*)$')
	if audio then
		package.loaded['audio.currentsystem'] = audio
	end

	-- override editor -- for distributions without ImGui
	if arg == 'editor=nil' then
		package.loaded['base.script.singleton.editor'] = function() end
	end
end


-- setup mod order  (todo store dependencies and add them accordingly?)
local modio = require 'base.script.singleton.modio'
modio.search = table{'base'}

-- [[ zeta
modio.search:insert(1, 'zeta')
modio.levelcfg = {
	path = 'gen',
	--path = 'reboot',
	--path = 'start',
	--path = 'start original',
}
--]]

-- run main
local main = require 'base.script.main'
main()
