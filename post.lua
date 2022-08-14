#!/usr/bin/env lua

local os = require 'ext.os'	-- make os.execute backwards-compatible

local function exec(cmd)
	print(cmd)
	assert(os.execute(cmd))
end


-- first zip the dir itself - before the dists have been copied into subdirs
exec('cd .. && 7z a zeta2d.7z zeta2d/')
exec('mkdir dist')
exec('mv ../zeta2d.7z dist/')
exec('scp -i ~/Documents/christopheremoore.net/digitalocean_christopheremoore.com_rsa dist/zeta2d.7z root@christopheremoore.net:/var/www/christopheremoore.net/')

for _,dist in ipairs{'osx', 'win32'} do
	exec('./package.lua '..dist)
	exec('mv dist/'..dist..' dist/zeta2d')
	exec('cd dist && 7z a zeta2d-'..dist..'.7z zeta2d/')
	exec('scp -i ~/Documents/christopheremoore.net/digitalocean_christopheremoore.com_rsa dist/zeta2d-'..dist..'.7z root@christopheremoore.net:/var/www/christopheremoore.net/')
	exec('mv dist/zeta2d dist/'..dist)
end

exec('rm -fr dist')
