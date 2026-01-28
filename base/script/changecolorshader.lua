local GLProgram = require 'gl.program'

local function createChangeColorShader(R)
	local changeColorShader = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
in vec4 vertex;
out vec2 tc;

uniform mat4 mvProjMat;

uniform vec4 defaultRect;
uniform vec4 defaultTexRect;	//xy = texcoord offset, zw = texcoord size
uniform vec4 defaultCenterAndRot;	//zw = cos(angle), sin(angle)

void main() {
	tc = defaultTexRect.xy + defaultTexRect.zw * vertex;

	vec2 rxy = vertex * defaultRect.zw - defaultCenterAndRot.xy;
	rxy = vec2(
		rxy.x * defaultCenterAndRot.z - rxy.y * defaultCenterAndRot.w,
		rxy.y * defaultCenterAndRot.z + rxy.x * defaultCenterAndRot.w
	);
	rxy += defaultCenterAndRot.xy + defaultRect.xy;
	gl_Position = mvProjMat * vec4(rxy, 0., 1.);
}
]],
		fragmentCode=[[
in vec2 tc;
out vec4 fragColor;
uniform vec4 color;
uniform sampler2D tex;
uniform vec3 colorFrom;
uniform float colorRange;
void main() {
	//TODO do distance in HSV ...
	fragColor = texture2D(tex, tc);
	float colorDist = length(fragColor.rgb - colorFrom);
	float lerp = clamp(0., 1. - colorDist / colorRange, 1.);
	fragColor = mix(fragColor, color, lerp);
}
]],
		uniforms={tex=0},
	}
	return changeColorShader
end

return createChangeColorShader
