#!/usr/bin/env lua

local function exec(cmd)
	print(cmd)
	if _VERSION == 'Lua 5.1' and not ffi then
		assert(os.execute(cmd)==0)
	else
		assert(os.execute(cmd))
	end
end


-- first zip the dir itself - before the dists have been copied into subdirs
exec('cd .. && 7z a dumpworld.7z dumpworld/')
os.execute('mkdir dist')
exec('mv ../dumpworld.7z dist/')
exec('scp -i ~/Documents/.christopheremoore.net/digitalocean_christopheremoore.com_rsa dist/dumpworld.7z root@christopheremoore.net:/var/www/christopheremoore.net/')

for _,dist in ipairs{'osx', 'win32'} do
	exec('./package.lua '..dist)
	exec('mv dist/'..dist..' dist/dumpworld')
	exec('cd dist && 7z a dumpworld-'..dist..'.7z dumpworld/')
	exec('scp -i ~/Documents/.christopheremoore.net/digitalocean_christopheremoore.com_rsa dist/dumpworld-'..dist..'.7z root@christopheremoore.net:/var/www/christopheremoore.net/')
	exec('mv dist/dumpworld dist/'..dist)
end

exec('rm -fr dist')
