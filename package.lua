#!/usr/bin/env luajit
-- script to make an .app package

local target = ...

local ffi = require 'ffi'
require 'ext'

-- TODO make sure name has no spaces/symbols, or is properly escaped for all these cp commands: 
local name = 'DumpWorld'	-- or whatever you want to call the .app

local function fixpath(path)
	if ffi.os == 'Windows' then
		return path:gsub('/','\\')
	else
		return path
	end
end

local function mkdir(dir)
	local cmd = 'mkdir '..fixpath(dir)
	print(cmd)
	os.execute(cmd)
end

local function exec(cmd)
	print(cmd)
	if _VERSION == 'Lua 5.1' and not ffi then
		assert(os.execute(cmd)==0)
	else
		assert(os.execute(cmd))
	end
end

-- TODO replace all exec(cp) and exec(rsync) with my own copy
-- or at least something that works on all OS's

local function copyToDir(file,dir)
	if ffi.os == 'Windows' then
		-- /Y means suppress error on overwriting files
		exec('copy '..fixpath(file)..' '..fixpath(dir)..' /Y')
	else
		exec('cp '..file..' '..dir)
	end
end

-- the platform-independent stuff:
local function copyBody(destDir)
	copyToDir('init.lua', destDir)
	copyToDir('package.lua', destDir)
	-- internal project folders
	for _,dir in ipairs{
		-- TODO enable according to which is used init.lua & its deps
		'base',
		'zeta',
	} do
		if ffi.os == 'Windows' then
			exec('xcopy '..dir..' '..fixpath(destDir)..'\\'..dir..' /E /I /Y')
		else
			exec('cp -R '..dir..' '..destDir)
		end
	end
	-- external project folders
	-- only copy *.lua files ... or at least don't copy .git files
	for _,dir in ipairs{
		'ext',
		'glapp',
		--'imguiapp',	-- TODO: not for windows only
		'vec',
		'parser',
		'image',
		'audio',
		'netrefl',
		'resourcecache',
		'threadmanager',
		'simplexnoise',
		'gui',
		'gl',
		--'gles2'	-- for android only
	} do
		if ffi.os == 'Windows' then
			exec('xcopy ..\\'..dir..'\\*.lua '..fixpath(destDir)..'\\'..dir..' /E /I /Y')
		else
			exec("rsync -avm --include='*.lua' -f 'hide,! */' ../"..dir.." "..destDir)
		end
	end
	-- ffi bindings
	mkdir(destDir..'/ffi')
	for _,fn in ipairs{'sdl','OpenGL','glu','OpenAL','OpenALUT','png','imgui'} do
		copyToDir('../ffi/'..fn..'.lua', destDir..'/ffi')
	end
	mkdir(destDir..'/ffi/c')
	for _,fn in ipairs{'setjmp','stdio','stdlib','string','time'} do
		copyToDir('../ffi/c/'..fn..'.lua', destDir..'/ffi/c')
	end
	mkdir(destDir..'/ffi/c/sys')
	for _,fn in ipairs{'time'} do
		copyToDir('../ffi/c/sys/'..fn..'.lua', destDir..'/ffi/c/sys')
	end
end

mkdir('dist')

-- the windows-specific stuff:
local function makeWin(arch)
	assert(arch == 'x86' or arch == 'x64', "expected arch to be x86 or x64")
	local bits = assert( ({x86='32',x64='64'})[arch] )
	local osDir = 'dist/win'..bits
	mkdir(osDir)
	local runBat = osDir..'/run.bat'

-- TODO for now windows runs with no audio and no editor.  eventually add OpenAL and C/ImGui support. 
	file[runBat] = [[
cd data
set PATH=%PATH%;bin\Windows\]]..arch..'\n'..[[
set LUA_PATH=./?.lua;./?/?.lua
set LUAJIT_LIBPATH=.
luajit.exe init.lua editor=nil audio=null libpngVersion=1.5.13 > out.txt 2> err.txt
cd ..
]]

	local dataDir = osDir..'/data'
	mkdir(dataDir)
	mkdir(dataDir..'/bin')
	mkdir(dataDir..'/bin/Windows')
	local binDir = dataDir..'/bin/Windows/'..arch
	mkdir(binDir)
	
	-- copy luajit
	copyToDir('../ufo/bin/Windows/'..arch..'/luajit.exe', binDir)
	
	-- copy body
	copyBody(dataDir)

	-- copy ffi windows dlls's
	for _,fn in ipairs{
		'luajit',
		'sdl',
		'png',
		'z',	-- needed by png
		'regal',	-- I thought I commented out my OpenGL loading of regal ...
	} do
		for _,ext in ipairs{'dll','lib'} do
			copyToDir('../ufo/bin/Windows/'..arch..'/'..fn..'.'..ext, binDir)
		end
	end
end

local function makeOSX()
	-- the osx-specific stuff:
	local osDir = 'dist/osx'
	mkdir(osDir)
	mkdir(osDir..'/'..name..'.app')
	local contentsDir = osDir..'/'..name..'.app/Contents'
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
-- https://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
	file[runSh] = [[
#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR/../Resources
export LUA_PATH="./?.lua;./?/?.lua"
export LUAJIT_LIBPATH="."
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
	for _,fn in ipairs{'sdl','libpng','libalut','libimgui'} do
		exec('cp ../bin/OSX/'..fn..'.dylib '..resourcesDir..'/bin/OSX')
	end
end


if target == 'all' or target == 'osx' then makeOSX() end
if target == 'all' or target == 'win32' then makeWin('x86') end
--if target == 'all' or target == 'win64' then makeWin('x64') end -- ufo only runs the 64 bit versions for amd ...
