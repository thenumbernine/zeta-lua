#if defined(VERTEX_SHADER)

varying vec2 tc;

uniform float viewSize;		//half width of ortho
uniform vec4 viewport;		//xy=xy, zw=wh

uniform vec2 viewPos;

uniform vec2 levelSize;	// level size, in tiles

void main() {
	float aspectRatio = viewport.z / viewport.w;

	//gl_Vertex is in [0,1]^2 unit screen space
	tc = gl_Vertex.xy;	
	//convert to [-1,1]^2 unit screen space
	tc *= 2.;
	tc -= 1.;
	//inverse ortho transform
	tc.y /= aspectRatio;
	tc *= viewSize;
	//inverse modelview transform
	tc += viewPos;
	//convert to tile coordinates
	tc -= 1.;
	tc /= levelSize;
	
	gl_Position = ftransform();
}

#endif	//VERTEX_SHADER
#if defined(FRAGMENT_SHADER)

//[0,1] normalized-world coordinates 
//use tc * levelSize + 1 to get the world coordinates
varying vec2 tc;	

uniform vec2 levelSize;


// min of the bbox of the viewport, in world coordinates
//used by bg for scrolling effect
uniform vec2 viewMin;

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

vec4 applyBackgroundTex(vec4 fragColor, vec2 pos) {
	
	// background color
	float bgIndexV = texture2D(backgroundTex, tc).x;
	
	float bgIndex = lumToUInt8(bgIndexV);
	if (bgIndex == 0.) return fragColor;	//TODO epsilon?

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
	fragColor.rgb = mix(fragColor.rgb, backgroundColor.rgb, backgroundColor.a);
	return fragColor;
}

vec4 applyTileForColor(vec4 fragColor, vec2 posInTile, vec2 tileIndexV) {
	float tileIndex = lumAlphaToUInt16(tileIndexV);
	if (tileIndex == 0.) return fragColor;	//TODO epsilon?

	tileIndex = tileIndex - 1.;
	float ti = mod(tileIndex, texpackTexSizeInTiles.x);
	float tj = (tileIndex - ti) / texpackTexSizeInTiles.x;
	//ti = floor(ti + .5);
	//tj = floor(tj + .5);
	
	// hmm, stamp stuff goes here, do I want to keep it?
	
	vec4 tileColor = texture2D(texpackTex, (vec2(ti, tj) + vec2(posInTile.x, 1. - posInTile.y)) / texpackTexSizeInTiles);
	fragColor.rgb = mix(fragColor.rgb, tileColor.rgb, tileColor.a);
	return fragColor;
}

vec4 applyBgTileTex(vec4 fragColor, vec2 posInTile) {
	return applyTileForColor(fragColor, posInTile, texture2D(bgTileTex, tc).zw);
}

vec4 applyFgTileTex(vec4 fragColor, vec2 posInTile) {
	return applyTileForColor(fragColor, posInTile, texture2D(fgTileTex, tc).zw);
}

vec2 rot2D(vec2 v, float angle) {
	vec2 a = vec2(cos(angle), sin(angle));
	return vec2(
		v.x * a.x - v.y * a.y,
		v.x * a.y + v.y * a.x);
}

vec4 applySprite(vec4 fragColor, vec2 pos, vec2 posInTile) {
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
	if (spriteListOffset < .1) return fragColor;	// 0 means none
#if 0
	return vec4(
		spriteListOffset,
		spriteListOffset,
		spriteListOffset,
		1.);
#endif
	spriteListOffset = spriteListOffset - 1.;	//change from 1-based to 0-based

#if 0
	if (spriteListOffset < .1) return vec4(1., 1., 1., 1.);
	if (spriteListOffset < 1.1) return vec4(1., 0., 0., 1.);
	if (spriteListOffset < 2.1) return vec4(1., 1., 0., 1.);
	if (spriteListOffset < 3.1) return vec4(0., 1., 0., 1.);
	if (spriteListOffset < 4.1) return vec4(0., 1., 1., 1.);
	if (spriteListOffset < 5.1) return vec4(0., 0., 1., 1.);
	return vec4(1., 0., 1., 1.);
#endif

	//using GL_LUMINANCE_ALPHA:
	//vec2 spriteListCountV = texture2D(spriteListTex, vec2(.5, (spriteListOffset + .5) / spriteListMax)).zw;
	//float spriteListCount = lumAlphaToUInt16(spriteListCountV);
	//using GL_RGBA32F:
	float spriteListCount = texture2D(spriteListTex, vec2(.5, (spriteListOffset + .5) / spriteListMax)).x;

#if 0
	if (spriteListCount < .1) return vec4(1., 1., 1., 1.);
	if (spriteListCount < 1.1) return vec4(1., 0., 0., 1.);
	if (spriteListCount < 2.1) return vec4(1., 1., 0., 1.);
	if (spriteListCount < 3.1) return vec4(0., 1., 0., 1.);
	if (spriteListCount < 4.1) return vec4(0., 1., 1., 1.);
	if (spriteListCount < 5.1) return vec4(0., 0., 1., 1.);
	return vec4(1., 0., 1., 1.);
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
			
			fragColor.rgb = mix(fragColor.rgb, texColor.rgb, texColor.a);
		}
	}

	return fragColor;
}


void main() {
	vec2 pos = tc * levelSize + 1.;
	vec2 posInTile = pos - floor(pos);

	vec4 fragColor = vec4(0.);
	fragColor = applyBackgroundTex(fragColor, pos);			//operates on gl_FragColor	
	fragColor = applyBgTileTex(fragColor, posInTile);		//operates on gl_FragColor
	fragColor = applySprite(fragColor, pos, posInTile);			//operates on gl_FragColor
	fragColor = applyFgTileTex(fragColor, posInTile);		//operates on gl_FragColor
	
	//hmm, how to handle alpha, since this won't mix the same as applying these two layers separately
	fragColor.a = 1.;

	gl_FragColor = fragColor;
}

#endif	//FRAGMENT_SHADER
