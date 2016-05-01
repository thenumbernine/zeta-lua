require 'ext'

local sprites = {
	{name='grasstile', dir='grasstile', frames={stand='stand.png'}},
	{
		name='cursor',
		dir='cursor',
		frames={
			move='move.png',
			cantlook='cantlook.png',
			look='look.png',
			attack='attack.png',
		},
	},
}

table.append(sprites, ([[
banon
celes
cyan
edgar
gau
ghost
gogo
imp
kefka
leo
locke
merchant
mog
morphedTerra
relm
sabin
setzer
shadow
soldier
strago
terra
umaro
]]):trim():split('\n'):map(function(v) return {
	name='terra',
	dir='terra',
	frames={
		cast1='cast1.png',
		cast2='cast2.png',
		dead='dead.png',
		dead2='dead2.png',
		eyesclosed='eyesclosed.png',
		finger1='finger1.png',
		finger2='finger2.png',
		growl='growl.png',
		handsupd='handsupd.png',
		handsupl1='handsupl1.png',
		handsupl2='handsupl2.png',
		handsupu='handsupu.png',
		jikuu='jikuu.png',
		laugh1='laugh1.png',
		laugh2='laugh2.png',
		pain='pain.png',
		peeved='peeved.png',
		ready='ready.png',
		sadd='sadd.png',
		sadl='sadl.png',
		sadu='sadu.png',
		saluted1='saluted1.png',
		saluted2='saluted2.png',
		saluteu1='saluteu1.png',
		saluteu2='saluteu2.png',
		stand='stand.png',
		standd='standd.png',
		standl='standl.png',
		standu='standu.png',
		startled='startled.png',
		swing='swing.png',
		tent='tent.png',
		walkd1='walkd1.png',
		walkd2='walkd2.png',
		walkl1='walkl1.png',
		walkl2='walkl2.png',
		walku1='walku1.png',
		walku2='walku2.png',
		winkd='winkd.png',
		winkl='winkl.png',
		wound='wound.png',
	},
	seqs={
		walku={'standu', 'walku1', 'standu', 'walku2', freq=8},
		walkd={'standd', 'walkd1', 'standd', 'walkd2', freq=8},
		walkl={'standl', 'walkl1', 'standl', 'walkl2', freq=8},
	},
} end))

return sprites
