local function createChangeColorShader(R)
	local changeColorShader
	if R.glname == 'OpenGLES2' then	-- gles2
		changeColorShader = R:createShader{
			vertexCode = [[
uniform mat4 vtxmat;
uniform mat4 texmat;
attribute vec4 pos;
varying vec2 tc;
void main() {
	tc = (texmat * pos).xy;
	gl_Position = vtxmat * pos;
}
]],
			fragmentCode=[[
precision mediump float;
uniform vec4 color;
uniform sampler2D tex;
varying vec2 tc;
uniform vec3 colorFrom;
uniform float colorRange;
void main() {
	//TODO do distance in HSV ...
	gl_FragColor = texture2D(tex, tc);
	float colorDist = length(gl_FragColor.rgb - colorFrom);
	float lerp = clamp(0., 1. - colorDist / colorRange, 1.);
	gl_FragColor = mix(gl_FragColor, color, lerp);
}
]],
			attributes={'pos'},
			uniforms={'colorFrom','colorRange','vtxmat','texmat','color','tex'},
		}	
	else	-- default opengl
		changeColorShader = R:createShader{
			vertexCode = [[
varying vec4 color;
varying vec2 tc;
void main() {
	tc = gl_MultiTexCoord0.xy;
	color = gl_Color;
	gl_Position = ftransform();
}
]],
			fragmentCode=[[
varying vec2 tc;
varying vec4 color;
uniform sampler2D tex;
uniform vec3 colorFrom;
uniform float colorRange;
void main() {
	//TODO do distance in HSV ...
	gl_FragColor = texture2D(tex, tc);
	float colorDist = length(gl_FragColor.rgb - colorFrom);
	float lerp = clamp(0., 1. - colorDist / colorRange, 1.);
	gl_FragColor = mix(gl_FragColor, color, lerp);
}
]],
			uniforms = {'tex', 'colorFrom', 'colorRange'},
		}
	end
	return changeColorShader
end
return createChangeColorShader
