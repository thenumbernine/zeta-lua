#!/usr/bin/env lua -lluarocks.require
-- script to make an .app package
require 'ext'
local lfs = require 'lfs'

-- TODO make sure name has no spaces/symbols, or is properly escaped for all these cp commands: 
local name = 'DumpWorld'	-- or whatever you want to call the .app

local function mkdir(dir)
	print('mkdir '..dir)
	lfs.mkdir(dir)
end

local function exec(cmd)
	print(cmd)
	if _VERSION == 'Lua 5.1' then
		assert(os.execute(cmd)==0)
	else
		assert(os.execute(cmd))
	end
end

-- TODO replace all exec(cp) and exec(rsync) with my own copy
-- or at least something that works on all OS's

-- the platform-independent stuff:
local function copyBody(destDir)
	-- basically copy everything except 'dist'
	-- if you wanted to get specific, only cop what inside 'init.lua' says the dir search paths uses
	exec('cp init.lua '..destDir)
	-- internal project folders
	for _,dir in ipairs{'base','brightmoon','mario','metroid','zeta'} do
		exec('cp -R '..dir..' '..destDir)
	end
	-- external project folders
	-- only copy *.lua files ... or at least don't copy .git files
	for _,dir in ipairs{'ext','glapp','vec','parser','image','audio','netrefl','resourcecache','threadmanager','simplexnoise','gui','gl'
		--,'gles2'	-- for android only
	} do
		exec("rsync -avm --include='*.lua' -f 'hide,! */' ../"..dir.." "..destDir)
	end
	-- ffi bindings
	mkdir(destDir..'/ffi')
	for _,fn in ipairs{'sdl','OpenGL','glu','OpenAL','png'} do
		exec('cp ../ffi/'..fn..'.lua '..destDir..'/ffi')
	end
	mkdir(destDir..'/ffi/c')
	for _,fn in ipairs{'setjmp','stdio','stdlib','string','time'} do
		exec('cp ../ffi/c/'..fn..'.lua '..destDir..'/ffi/c')
	end
	mkdir(destDir..'/ffi/c/sys')
	for _,fn in ipairs{'time'} do
		exec('cp ../ffi/c/sys/'..fn..'.lua '..destDir..'/ffi/c/sys')
	end
end

mkdir('dist')

-- the windows-specific stuff:
local function makeWin64()
	local win64Dir = 'dist/win64'
	mkdir(win64Dir)
	local runBat = win64Dir..'/run.bat'
	file[runBat] = [[
set LUA_PATH = "data/?.lua;data/?/?.lua"
set LUAJIT_LIBPATH = "data"
data\luajit.exe
]]

	local dataDir = win64Dir..'/data'
	mkdir(dataDir)

	-- copy luajit
	exec('cp ../ufo/bin/Windows/x64/luajit.exe '..dataDir)
	exec('cp ../ufo/bin/Windows/x64/luajit.dll '..dataDir)
	exec('cp ../ufo/bin/Windows/x64/luajit.lib '..dataDir)

	-- copy body
	copyBody(dataDir)

	-- copy ffi wind64 so's
	mkdir(dataDir..'/bin')
	mkdir(dataDir..'/bin/Windows')
	mkdir(dataDir..'/bin/Windows/x64')
	for _,fn in ipairs{'sdl','png'} do
		for _,ext in ipairs{'dll','lib','pdb'} do
			exec('cp ../ufo/bin/Windows/x64/'..fn..'.'..ext..' '..dataDir..'/bin/Windows/x64')
		end
	end
end

local function makeOSX()
	-- the osx-specific stuff:
	local osxDir = 'dist/osx'
	mkdir(osxDir)
	mkdir(osxDir..'/'..name..'.app')
	local contentsDir = osxDir..'/'..name..'.app/Contents'
	mkdir(contentsDir)
	file[contentsDir..'/PkgInfo'] = 'APPLhect'
	file[contentsDir..'/Info.plist'] = [[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>]]..name..[[</string>
	<key>CFBundleIdentifier</key>
	<string>net.christopheremoore.]]..name..[[</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleIconFile</key>
	<string>Icons</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleDocumentTypes</key>
	<array/>
	<key>CFBundleExecutable</key>
	<string>run.sh</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>1.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleSignature</key>
	<string>hect</string>
	<key>NSMainNibFile</key>
	<string>MainMenu</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>]]

	local macOSDir = contentsDir..'/MacOS'
	mkdir(macOSDir)
	local runSh = macOSDir..'/run.sh' 
	file[runSh] = [[
#!/usr/bin/env bash
# https://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR/../Resources
export LUA_PATH="./?.lua;./?/?.lua"
export LUAJIT_LIBPATH=.
./luajit init.lua > out.txt 2> err.txt
]]
	exec('chmod +x '..runSh)

	local resourcesDir = contentsDir..'/Resources'
	mkdir(resourcesDir)

	-- copy luajit
	local luajitPath = io.readproc('which luajit'):trim()
	exec('cp '..luajitPath..' '..resourcesDir)

	-- copy body
	copyBody(resourcesDir)
	
	-- ffi osx so's
	mkdir(resourcesDir..'/bin')
	mkdir(resourcesDir..'/bin/OSX')
	for _,fn in ipairs{'sdl','libpng'} do
		exec('cp ../bin/OSX/'..fn..'.dylib '..resourcesDir..'/bin/OSX')
	end
end

makeOSX()
makeWin64()
