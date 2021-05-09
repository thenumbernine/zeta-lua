#if defined(VERTEX_SHADER)

varying vec2 pos;
varying vec2 tc;
void main() {
	pos = gl_Vertex.xy;
	tc = gl_MultiTexCoord0.xy;
	gl_Position = ftransform();
}

#endif	//VERTEX_SHADER
#if defined(FRAGMENT_SHADER)

varying vec2 pos;
varying vec2 tc;

uniform vec2 viewMin;						//used by bg for scrolling effect

uniform float tileSize;

// per-tile in the map:
uniform sampler2D backgroundTex;			// unsigned char, reference into backgroundStructTex
uniform sampler2D fgTileTex;				// unsigned char <=> luminance_alpha, reference into texpackTex
uniform sampler2D bgTileTex;				// unsigned short <=> luminance_alpha, reference into texpackTex
uniform sampler2D spriteListOffsetTileTex;	// unsigned short <=> luminance_alpha, reference to spriteListTex

uniform sampler2D texpackTex;				// used by fgTileTex and bgTileTex 
uniform vec2 texpackTexSizeInTiles;

uniform sampler2D backgroundStructTex;		// used by backgroundTex, uses bgtexpackTex
uniform float backgroundStructTexSize;		// background_t <=> float4, stores all the background info

uniform sampler2D bgtexpackTex;				// used by backgroundStructTex
uniform vec2 bgtexpackTexSize;				// TODO bake this into the backgroundStruct data?

uniform sampler2D spriteListTex;			// unsigned short <=> luminance_alpha, reference to visSpriteTex
uniform float spriteListMax;

uniform sampler2D visSpriteTex;				// visSprite_t <=> float4, stores all the sprite info
uniform float visSpriteMax;

uniform sampler2D spriteSheetTex;			// used by visSpriteTex

float lumToUInt8(float lum) {
	return 255. * lum;
}

float lumAlphaToUInt16(vec2 lumAlpha) {
	return 255. * lumAlpha.x + 256. * 255. * lumAlpha.y;
}

void applyBackgroundTex() {
	
	// background color
	float bgIndexV = texture2D(backgroundTex, tc).x;
	
	float bgIndex = lumToUInt8(bgIndexV);
	if (bgIndex == 0.) return;	//TODO epsilon?

	// lookup the background region from an array/texture somewhere ...
	// it should specify x, y, w, h, scaleX, scaleY, scrollX, scrollY
	// so 8 channels per background in all
	float u = (bgIndex - .5) / backgroundStructTexSize;
	vec4 xywh = texture2D(backgroundStructTex, vec2(.25, u));
	vec2 xy = xywh.xy;
	vec2 wh = xywh.zw;
	vec4 scaleScroll = texture2D(backgroundStructTex, vec2(.75, u));
	vec2 scale = scaleScroll.xy;
	vec2 scroll = scaleScroll.zw;

	vec2 uv = pos - viewMin * scroll;
	uv.y = 1. - uv.y;
	uv /= scale;
	uv = mod(uv, 1.);
	uv = (uv * wh + xy) / bgtexpackTexSize;
	vec4 backgroundColor = texture2D(bgtexpackTex, uv);
	
	gl_FragColor.rgb = mix(gl_FragColor.rgb, backgroundColor.rgb, backgroundColor.a);
}

void applyTileForColor(vec2 posInTile, vec2 tileIndexV) {
	float tileIndex = lumAlphaToUInt16(tileIndexV);
	if (tileIndex == 0.) return;	//TODO epsilon?

	tileIndex = tileIndex - 1.;
	float ti = mod(tileIndex, texpackTexSizeInTiles.x);
	float tj = (tileIndex - ti) / texpackTexSizeInTiles.x;
	//ti = floor(ti + .5);
	//tj = floor(tj + .5);
	
	// hmm, stamp stuff goes here, do I want to keep it?
	
	vec4 tileColor = texture2D(texpackTex, (vec2(ti, tj) + vec2(posInTile.x, 1. - posInTile.y)) / texpackTexSizeInTiles);
	gl_FragColor.rgb = mix(gl_FragColor.rgb, tileColor.rgb, tileColor.a);
}

void applyBgTileTex(vec2 posInTile) {
	applyTileForColor(posInTile, texture2D(bgTileTex, tc).zw);
}

void applyFgTileTex(vec2 posInTile) {
	applyTileForColor(posInTile, texture2D(fgTileTex, tc).zw);
}

vec2 rot2D(vec2 v, float angle) {
	vec2 a = vec2(cos(angle), sin(angle));
	return vec2(
		v.x * a.x - v.y * a.y,
		v.x * a.y + v.y * a.x);
}

void applySprite(vec2 posInTile) {
	// raytrace through sprites at this tile
	// 1-based, 0 == no sprites
	//using GL_LUMINANCE_ALPHA:
	//vec2 spriteListOffsetV = texture2D(spriteListOffsetTileTex, tc).zw;
	//float spriteListOffset = lumAlphaToUInt16(spriteListOffsetV);
	//using GL_RGBA32F:
	float spriteListOffset = texture2D(spriteListOffsetTileTex, tc).x;
	//how come other lumAlphaToUInt16 in the background can compare exactly to zero?
	// but this one is near zero
	//something is wrong with this buffer reading
	if (spriteListOffset < .1) return;	// 0 means none
#if 0
	gl_FragColor.rgb = vec3(
		spriteListOffset,
		spriteListOffset,
		spriteListOffset
	);
	return;
#endif
	spriteListOffset = spriteListOffset - 1.;	//change from 1-based to 0-based

#if 0
	if (spriteListOffset < .1) {
		gl_FragColor.rgb = vec3(1., 1., 1.);
	} else if (spriteListOffset < 1.1) {
		gl_FragColor.rgb = vec3(1., 0., 0.);
	} else if (spriteListOffset < 2.1) {
		gl_FragColor.rgb = vec3(1., 1., 0.);
	} else if (spriteListOffset < 3.1) {
		gl_FragColor.rgb = vec3(0., 1., 0.);
	} else if (spriteListOffset < 4.1) {
		gl_FragColor.rgb = vec3(0., 1., 1.);
	} else if (spriteListOffset < 5.1) {
		gl_FragColor.rgb = vec3(0., 0., 1.);
	} else {
		gl_FragColor.rgb = vec3(1., 0., 1.);
	}
	return;
#endif

	//using GL_LUMINANCE_ALPHA:
	//vec2 spriteListCountV = texture2D(spriteListTex, vec2(.5, (spriteListOffset + .5) / spriteListMax)).zw;
	//float spriteListCount = lumAlphaToUInt16(spriteListCountV);
	//using GL_RGBA32F:
	float spriteListCount = texture2D(spriteListTex, vec2(.5, (spriteListOffset + .5) / spriteListMax)).x;

#if 0
	if (spriteListCount < .1) {
		gl_FragColor.rgb = vec3(1., 1., 1.);
	} else if (spriteListCount < 1.1) {
		gl_FragColor.rgb = vec3(1., 0., 0.);
	} else if (spriteListCount < 2.1) {
		gl_FragColor.rgb = vec3(1., 1., 0.);
	} else if (spriteListCount < 3.1) {
		gl_FragColor.rgb = vec3(0., 1., 0.);
	} else if (spriteListCount < 4.1) {
		gl_FragColor.rgb = vec3(0., 1., 1.);
	} else if (spriteListCount < 5.1) {
		gl_FragColor.rgb = vec3(0., 0., 1.);
	} else {
		gl_FragColor.rgb = vec3(1., 0., 1.);
	}
	return;
#endif

	//now cycle through the sprites on this tile
	spriteListOffset = spriteListOffset + 1.;
	for (float i = 0.; i < spriteListCount; ++i) {
		
		//using GL_LUMINANCE_ALPHA:
		//vec2 spriteIndexV = texture2D(spriteListTex, vec2(.5, (spriteListOffset + .5) / spriteListMax)).zw;
		//float spriteIndex = lumAlphaToUInt16(spriteIndexV);
		//using GL_RGBA32F:
		float spriteIndex = texture2D(spriteListTex, vec2(.5, (spriteListOffset + .5) / spriteListMax)).x;
		
		spriteListOffset = spriteListOffset + 1.;

		// now use spriteIndex for lookup in the visSpriteTex to get the sprite data
		// last, use the visSpriteTex
		// this is hardcoded to the visSprite_t structure:
		float u = (spriteIndex + .5) / visSpriteMax;
		
		//pull the struct
		vec4 xywh = texture2D(visSpriteTex, vec2( (0. + .5) / 4., u));
		vec4 txywh = texture2D(visSpriteTex, vec2( (1. + .5) / 4., u));
		vec4 rgba = texture2D(visSpriteTex, vec2( (2. + .5) / 4., u));
		vec4 rot = texture2D(visSpriteTex, vec2( (3. + .5) / 4., u));	// rotation center, angle

		// pull the fields
		vec2 xy = xywh.xy;
		vec2 size = xywh.zw;
		vec2 txy = txywh.xy;
		vec2 twh = txywh.zw;
		vec2 rc = rot.xy;
		float angle = rot.z;

//TODO rc
		/*
		now, based on the tc, find the sprite position, lookup texel, and lookup frame info in sprite sheet
		*/
		vec2 uv = rot2D(pos.xy - xy, -angle) / size;
		if (uv.x >= 0. && uv.x <= 1. && uv.y >= 0. && uv.y <= 1.) {
			uv = uv * twh + txy;
			vec4 texColor = texture2D(spriteSheetTex, uv);
		
			// technically correct, but only used in the shaders that I haven't implemented in the raytracer yet.
			//texColor *= rgba;
			
			gl_FragColor.rgb = mix(gl_FragColor.rgb, texColor.rgb, texColor.a);
		}
	}
}


void main() {
	vec2 posInTile = pos - floor(pos);

	gl_FragColor = vec4(0.);

	applyBackgroundTex();			//operates on gl_FragColor
	
	applyBgTileTex(posInTile);		//operates on gl_FragColor
	applySprite(posInTile);			//operates on gl_FragColor
	applyFgTileTex(posInTile);		//operates on gl_FragColor
	
	//hmm, how to handle alpha, since this won't mix the same as applying these two layers separately
	gl_FragColor.a = 1.;
}

#endif	//FRAGMENT_SHADER
