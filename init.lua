#!/usr/bin/env luajit

-- setup global env:
local table = require 'ext.table'

numPlayers=numPlayers or 1

--[[
cmdline args for tweaking the environment / packages to get things working
TODO use ext.cmdline?
--]]
local glname
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

	glname = arg:match'^gl=(.*)$'
end


require 'gl.setup'(glname)				-- nil for default to OpenGL:
--require 'gl.setup' 'OpenGLES1'		-- for desktop OpenGL
--require 'gl.setup' 'OpenGLES1'		-- for GLES1		-- doesn't support shaders
--require 'gl.setup' 'OpenGLES2'		-- for GLES2		-- doesn't support float textures
--require 'gl.setup' 'OpenGLES3' 	 	-- for GLES3		-- works ... except in stupid OSX ... and except in stupid Windows ... and I need to convert the font renderer to drawbuffers ... or convert the font render to just use cimgui
--require 'gl.setup'(require 'ffi'.os ~= 'Windows' and 'OpenGLES3' or nil)


-- setup mod order  (todo store dependencies and add them accordingly?)
local modio = require 'base.script.singleton.modio'
modio.search = table{'base'}

--[[ mario
modio.search:insert(1, 'mario')
modio.levelcfg = {

	music = 'music/cave.wav',
	--music = 'music/overworld.wav',

	--path = 'empty',
	path = 'test',
	--path = 'test2',
	--path = 'doors',		-- FIXME
	--path = 'fight',
	--path = 'mine',
	--path = 'mine2',
	--path = 'pswitch-fluids',
	--path = 'pswitch-platform',
	--path = 'race',

	-- this path has a template.png file in it (mario/maps/level1/template.png)
	--  so it doesn't need a "template = ..." to be uncommented
	--path = 'level1',
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

--[[ zeta
modio.search:insert(1, 'zeta')
--modio.search:insert'mario'	-- don't add this, it messes up the block types.
modio.levelcfg = {
	--blocksWide = 16, blocksHigh = 16,
	--path = 'reboot',
	--path = 'reboot2',
	--path = 'gen',
	--path = 'gen2',
	path = 'start',
	--path = 'start original',
	music = 'music/sb_aurora.wav',
}
--]]

--[[
modio.search:insert(1, 'brightmoon')
modio.levelcfg = {
	path = 'start',
	startPositions = {{25,25}},
}
--]]

--[[ madness
modio.search:insert(1, 'madness')
modio.levelcfg = {
	path = 'start',
}
--]]

-- [[ neko
modio.search:insert(1, 'neko')
modio.levelcfg = {
	music = 'music/overworld.wav',
	path = 'start',
}
--]]



-- run main
return modio:require 'script.main'()
