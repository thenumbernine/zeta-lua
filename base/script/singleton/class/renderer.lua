local ffi = require 'ffi'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local vec4x4f = require 'vec-ffi.vec4x4f'
local modio = require 'base.script.singleton.modio'

local Renderer = class()
Renderer.requireClasses = {}

do
	local gl = require 'gl'
	local GLTex2D = require 'gl.tex2d'
	local GLProgram = require 'gl.program'
	local GLSceneObject = require 'gl.sceneobject'

	local GLRenderer = Renderer:subclass()
	GLRenderer.glname = 'gl'
	Renderer.requireClasses.gl = GLRenderer

	function GLRenderer:init(gl_)

		self.projMat = vec4x4f():setIdent()
		self.mvMat = vec4x4f():setIdent()
		self.mvProjMat = vec4x4f():setIdent()

		self.identMat = vec4x4f():setIdent()

		local texsys = modio:require 'script.singleton.texsys'
		texsys:setVars(gl, GLTex2D, {
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		})

		-- default shader
		self.shader = GLProgram{
			version = 'latest',
			precision = 'best',
			vertexCode = [[
layout(location=0) in vec2 vertex;
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
			fragmentCode = [[
in vec2 tc;

out vec4 fragColor;

uniform vec4 defaultColor;
uniform sampler2D tex;

void main() {
	fragColor = defaultColor * texture(tex, tc);
}
]],
			uniforms = {
				defaultColor = {1,1,1,1},
				tex = 0,
			},
		}:useNone()

		self.drawObj = GLSceneObject{
			program = self.shader,
			vertexes = {
				usage = gl.GL_STATIC_DRAW,
				dim = 2,
				data = {
					0, 0,
					1, 0,
					0, 1,
					1, 1,
				},
			},
			geometry = {
				mode = gl.GL_TRIANGLE_STRIP,
			},
		}
	end
	function GLRenderer:ortho(...)
		self.projMat:setOrtho(...)
		self.mvProjMat:mul4x4(self.projMat, self.mvMat)
	end
	function GLRenderer:viewPos(x,y)
		self.mvMat:setTranslate(-x,-y,0)
		self.mvProjMat:mul4x4(self.projMat, self.mvMat)
	end
	local f4 = ffi.new('float[4]')
	function GLRenderer:quad(
		x,y,
		w,h,
		tx,ty,
		tw,th,
		angle,
		r,g,b,a,
		shader,
		uniforms,
		rcx, rcy
	)
		rcx = rcx or 0
		rcy = rcy or 0

		shader = shader or self.shader
		shader:use()
		if shader.uniforms.mvProjMat then
			gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_TRUE, self.mvProjMat.ptr)
		end
		if uniforms then
			shader:setUniforms(uniforms)
		end

		local costh, sinth
		if angle then
			local radians = math.rad(angle)
			costh = math.cos(radians)
			sinth = math.sin(radians)
		else
			costh, sinth = 1, 0
		end
		-- and set default shader uniforms ...
		if shader.uniforms.defaultColor and r and g and b and a then
			gl.glUniform4f(shader.uniforms.defaultColor.loc, r, g, b, a)
		end
		if shader.uniforms.defaultRect then
			gl.glUniform4f(shader.uniforms.defaultRect.loc, x, y, w, h)
		end
		if shader.uniforms.defaultTexRect then
			gl.glUniform4f(shader.uniforms.defaultTexRect.loc, tx, ty, tw, th)
		end
		if shader.uniforms.defaultCenterAndRot then
			gl.glUniform4f(shader.uniforms.defaultCenterAndRot.loc, rcx, rcy, costh, sinth)
		end

		self.drawObj:draw{
			program = shader,
		}

		--shader:useNone()
	end
end

return Renderer
