#if defined(VERTEX_SHADER)

varying vec2 unitScreenCoord;	//[-1,1]^2 unit screen space

void main() {
	unitScreenCoord = gl_Vertex.xy;
	gl_Position = ftransform();
}

#endif	//VERTEX_SHADER
#if defined(FRAGMENT_SHADER)

varying vec2 unitScreenCoord;


uniform float viewSize;			//half width of ortho
uniform vec4 viewport;			//xy=xy, zw=wh
uniform float aspectRatioH_W;	//= h/w = viewport.w/viewport.z

uniform vec4 viewBBox;			//xy=min, zw=max, in world coords

uniform vec2 levelSize;			//level size, in tiles

uniform vec2 eyePos;			//position of player's eyes, in world coordinates

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

vec4 applyBackgroundTex(vec4 fragColor, vec2 pos, vec2 mapTC) {
	
	// background color
	float bgIndexV = texture2D(backgroundTex, mapTC).x;
	
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

	vec2 uv = pos - viewBBox.xy * scroll;
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

vec4 applyBgTileTex(vec4 fragColor, vec2 posInTile, vec2 mapTC) {
	return applyTileForColor(fragColor, posInTile, texture2D(bgTileTex, mapTC).zw);
}

vec4 applyFgTileTex(vec4 fragColor, vec2 posInTile, vec2 mapTC) {
	return applyTileForColor(fragColor, posInTile, texture2D(fgTileTex, mapTC).zw);
}

vec2 rot2D(vec2 v, float angle) {
	vec2 a = vec2(cos(angle), sin(angle));
	return vec2(
		v.x * a.x - v.y * a.y,
		v.x * a.y + v.y * a.x);
}

vec4 applySprite(vec4 fragColor, vec2 pos, vec2 posInTile, vec2 mapTC) {
	// raytrace through sprites at this tile
	// 1-based, 0 == no sprites
	//using GL_LUMINANCE_ALPHA:
	//vec2 spriteListOffsetV = texture2D(spriteListOffsetTileTex, mapTC).zw;
	//float spriteListOffset = lumAlphaToUInt16(spriteListOffsetV);
	//using GL_RGBA32F:
	float spriteListOffset = texture2D(spriteListOffsetTileTex, mapTC).x;
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

//TODO rc = rotation-center
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

vec4 getColorAtWorldPos(vec2 pos) {
	vec2 posInTile = pos - floor(pos);

	//convert to texcoords in map texture
	vec2 mapTC = (pos - 1.) / levelSize;

	vec4 fragColor = vec4(0.);
	fragColor = applyBackgroundTex(fragColor, pos, mapTC);			//operates on gl_FragColor	
	fragColor = applyBgTileTex(fragColor, posInTile, mapTC);		//operates on gl_FragColor
	fragColor = applySprite(fragColor, pos, posInTile, mapTC);			//operates on gl_FragColor
	fragColor = applyFgTileTex(fragColor, posInTile, mapTC);		//operates on gl_FragColor
	
	//hmm, how to handle alpha, since this won't mix the same as applying these two layers separately
	fragColor.a = 1.;

	return fragColor;
}

vec2 worldToUnitScreenPos(vec2 worldPos) {
	return (worldPos - viewBBox.xy) / (viewBBox.zw - viewBBox.xy);
}

vec2 unitScreenToWorldPos(vec2 unitScreenPos) {
	return unitScreenPos * (viewBBox.zw - viewBBox.xy) + viewBBox.xy;
}

vec2 worldToViewportPos(vec2 worldPos) {
	vec2 unitScreenPos = worldToUnitScreenPos(worldPos);
	return unitScreenPos * viewport.zw + viewport.xy;
}

vec2 viewportToWorldPos(vec2 viewportPos) {
	vec2 unitScreenPos = viewportPos / viewport.zw - viewport.xy;
	return unitScreenToWorldPos(unitScreenPos);
}

vec4 getColorAtViewportPos(vec2 viewportPos) {
	return getColorAtWorldPos(viewportToWorldPos(viewportPos));
}

float lenSq(vec3 a) {
	return dot(a, a);
}

void main() {
	//gl_Vertex is in [-1,1]^2 unit screen space
	vec2 pos = unitScreenCoord;
	//inverse ortho transform
	pos.y *= aspectRatioH_W;
	pos *= viewSize;
	//inverse modelview transform
	vec2 viewPos = .5 * (viewBBox.xy + viewBBox.zw);
	pos += viewPos;
	//and now we are in world-space

#if 0	//single sample
	//here's for a single sample:
	gl_FragColor = getColorAtWorldPos(pos);
#else	//raytrace


	vec2 tc = (unitScreenCoord + 1.) * .5 * viewport.zw;
	//now march from the view origin (pass this as a uniform ... pass bounds too) to 'tc'

	//how big is 1 tile, in pixels
	float tileSizeInPixels = .5 * viewport.z / viewSize;

	//assuming a tile is 16 texels, how many pixels in a texel?
	//float sizeOfATexelForTex16 = max(1., tileSizeInPixels / 16.);

	vec3 grey = vec3(.3, .6, .1);

	//vec2 origin = viewport.xy + .5 * viewport.zw;
	//origin.y += tileSizeInPixels;
	vec2 origin = worldToViewportPos(eyePos);
	
	vec2 raypos = origin;
	vec2 rayvel = tc - origin;
	float raylength = length(rayvel);
	float rayLInfLength = max(abs(rayvel.x), abs(rayvel.y));
	vec2 raydir = rayvel / raylength;

	//float numSteps = 100.;
	float numSteps = max(1., rayLInfLength);
	//numSteps = min(numSteps, 100.);	
	//if I have to cap the raytrace steps, then that means there are samples I'm missing, so how about I scale my step randomly to make up for it?

	vec4 color = vec4(1.);

//TODO numSteps should be l-inf dist of pixels covered
// TODO sampling below - esp transparency - should be step-independent
	float dlen = raylength / numSteps;
	for (float i = 0.; i < numSteps; ++i) {
		vec2 oldraypos = raypos;
		raypos += raydir * dlen;

		vec4 sampleColor = getColorAtViewportPos(raypos);
	
		
/* TODO 
add some extra render info into the buffer on how to transform the rays at each point

- transform ray direction (reflection/refraction effects)
- transform ray position (portals)
- transparency
*/

		//opacity==1 means ordinary rendering, no smearing
		//opacity==0 means fully smeared
		//float opacity = 1.;

		vec3 translateColor = vec3(248., 216., 32.) / 255.;		//yellow block color

		// this is for the transparency and refraction effect
		vec3 effectSrcColor = vec3(0., 0., 1.);
		//vec3 effectSrcColor = vec3(104., 104., 176.) / 255.;	// blue block color
		//vec3 effectSrcColor = vec3(34., 208., 56.) / 255.;	// which color was this?
		//vec3 effectSrcColor = vec3(0., 1., .5);

		//vec3 reflectEffectSrcColor = vec3(0., 1., 0.);
		vec3 reflectEffectSrcColor = vec3(0., 200., 0.) / 255.;
		
		float opacity = lenSq(sampleColor.rgb - effectSrcColor)
		//+ lenSq(sampleColor.rgb - reflectEffectSrcColor)
		;
		
		opacity -= .1;
		opacity *= 3.;
		opacity = clamp(opacity, 0., 1.);
		//opacity = smoothstep(.1, .8, opacity);
		
		//float refractivity = 0.;
		float refractivity = .05 * (1. - opacity);
		
		//opacity = 1. - sqrt(1. - opacity);	//pulls down, more at the bottom
		//opacity *= opacity;					//pulls down, more at the top
		//opacity = 1. - pow(1. - opacity, 1. / 8.);
		//opacity = pow(opacity, 8.);
		//opacity *= .1;
		//opacity = 1.;

		//now add color slope to raydir and normalize
		float l0m = dot(grey, getColorAtViewportPos(raypos).rgb);
		float lm0 = dot(grey, getColorAtViewportPos(raypos).rgb);
		float lp0 = dot(grey, getColorAtViewportPos(raypos).rgb);
		float l0p = dot(grey, getColorAtViewportPos(raypos).rgb);
		//float lmm = dot(grey, getColorAtViewportPos(raypos).rgb);
		//float lpm = dot(grey, getColorAtViewportPos(raypos).rgb);
		//float lmp = dot(grey, getColorAtViewportPos(raypos).rgb);
		//float lpp = dot(grey, getColorAtViewportPos(raypos).rgb);
		//float l00 = dot(grey, getColorAtViewportPos(raypos).rgb);

		// 1st order dx,dy
		vec2 dl = vec2(.5 * (lp0 - lm0), .5 * (l0p - l0m));
		// Sobel
		//vec2 dl = vec2(.25 * (lpp - lmp + 2. * (lp0 -lm0) + lpm - lmm), .25 * (lpp - lpm + 2. * (l0p -l0m) + lmp - lmm));
		
		dl = normalize(dl);
		//cheap I know
		raydir = normalize(mix(raydir, raydir + dl, refractivity));


		//cheap portal translations
		if (lenSq(sampleColor.rgb - translateColor) < .01) {
			raypos.y += tileSizeInPixels * 5.;
		}
		
		//cheap reflections
		if (lenSq(sampleColor.rgb - reflectEffectSrcColor) < .15) {
			raydir = normalize(raydir - 2. * dl * dot(raydir, dl));
			raypos = oldraypos + raydir * 2.;
		
			//and don't just reflect but also dim
			opacity = .9;
			sampleColor = vec4(0., 0., 0., 0.);
		}



		//color.a = opacity;
		color.a *= opacity;
		//color.a = 1. - color.a * (1. - opacity);
		
		color.rgb *= 1. - color.a;
		color.rgb += color.a * sampleColor.rgb;
	}
	
	gl_FragColor = vec4(color.rgb, 1.);

#endif
}

#endif	//FRAGMENT_SHADER
