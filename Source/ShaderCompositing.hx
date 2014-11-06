import openfl.display.BitmapData;
import openfl.geom.Matrix3D;
import openfl.gl.*;
import openfl.utils.*;

class ShaderCompositing {

	private static var fb_texture : GLTexture;
	private static var fb_framebuffer : GLFramebuffer;
	private static var fb_renderbuffer : GLRenderbuffer;
	private static var fb_vertexShader : GLShader;

	public static function init (maxWidth:Int, maxHeight:Int) : Void {

		fb_texture = GL.createTexture ();
        GL.bindTexture (GL.TEXTURE_2D, fb_texture);
        GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.REPEAT);
        GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.REPEAT);
        GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);

        GL.texImage2D (GL.TEXTURE_2D, 0, GL.RGBA, maxWidth, maxHeight, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);

        fb_framebuffer = GL.createFramebuffer ();
        GL.bindFramebuffer (GL.FRAMEBUFFER, fb_framebuffer);

        GL.framebufferTexture2D (GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, fb_texture, 0);

        fb_renderbuffer = GL.createRenderbuffer();
        GL.bindRenderbuffer (GL.RENDERBUFFER, fb_renderbuffer);
        GL.renderbufferStorage (GL.RENDERBUFFER, GL.DEPTH_COMPONENT, maxWidth, maxHeight);

        GL.framebufferRenderbuffer (GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, fb_renderbuffer);

        var status = GL.checkFramebufferStatus (GL.FRAMEBUFFER);
        switch (status) {

            case GL.FRAMEBUFFER_COMPLETE:

            default:
				throw ("FrameBuffer error");

        }

        GL.bindFramebuffer (GL.FRAMEBUFFER, null);

        var vertexSource =

			"attribute vec4 aPosition;
			attribute vec2 aTexCoord;
			varying vec2 vTexCoord;

			uniform mat4 uMatrix;

			void main (void) {

				vTexCoord = vec2 (aTexCoord.x, 1.0-aTexCoord.y); // flip y
				gl_Position = uMatrix * aPosition;

			}";

		fb_vertexShader = GLUtils.compileShader (vertexSource, GL.VERTEX_SHADER);

	}

	public static function uploadLayers (layers:Array<BitmapData>) : LayerGroup {

		var textures = new Array<GLTexture>();

		for (layer in layers) {

			var texture = GL.createTexture ();

			GL.bindTexture (GL.TEXTURE_2D, texture);
			GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
			GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
			GL.texImage2D (GL.TEXTURE_2D, 0, GL.RGBA, layer.width, layer.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, new UInt8Array (BitmapData.getRGBAPixels (layer.clone())));
			GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
			GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
			GL.bindTexture (GL.TEXTURE_2D, null);

			textures.push (texture);

		}

		return new LayerGroup (textures, layers[0].width, layers[0].height);

	}

	public static function composite (group:LayerGroup, fragmentShader:String, ?params:Array<{name:String, value:Dynamic, type:UniformType}>) : BitmapData {

		GL.bindFramebuffer (GL.FRAMEBUFFER, fb_framebuffer);

		var program = GLUtils.createProgram (fb_vertexShader, fragmentShader);
		GL.useProgram (program);

		var vertexAttribute = GL.getAttribLocation (program, "aPosition");
		var textureAttribute = GL.getAttribLocation (program, "aTexCoord");
		var matrixUniform = GL.getUniformLocation (program, "uMatrix");
		var imageUniform = GL.getUniformLocation (program, "uImage0");

		GL.enableVertexAttribArray (vertexAttribute);
		GL.enableVertexAttribArray (textureAttribute);
		GL.uniform1i (imageUniform, 0);
		
		if (params != null) {
			
			for (param in params) {
				
				var uni = GL.getUniformLocation (program, param.name);
				
				switch (param.type) {
				
					case Int:
						GL.uniform1i (uni, cast param.value);
						
					case Float:
						GL.uniform1f (uni, cast param.value);
						
					case Int2:
						GL.uniform2iv (uni, cast param.value);
						
					case Float2:
						GL.uniform2fv (uni, cast param.value);
						
					case Int3:
						GL.uniform3iv (uni, cast param.value);
						
					case Float3:
						GL.uniform3fv (uni, cast param.value);
						
					case Int4:
						GL.uniform4iv (uni, cast param.value);
						
					case Float4:
						GL.uniform4fv (uni, cast param.value);
					
				}
				
			}
			
		}

		GL.viewport (0, 0, group.width, group.height);

		GL.clearColor (0.0, 0.0, 0.0, 0.0);
		GL.clear (GL.COLOR_BUFFER_BIT);

		GL.enable (GL.BLEND);
		GL.blendFunc (GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);

		GL.uniformMatrix4fv (matrixUniform, false, group.matrix);

		GL.bindBuffer (GL.ARRAY_BUFFER, group.buffer);
		GL.vertexAttribPointer (vertexAttribute, 3, GL.FLOAT, false, 5 * Float32Array.SBYTES_PER_ELEMENT, 0);
		GL.vertexAttribPointer (textureAttribute, 2, GL.FLOAT, false, 5 * Float32Array.SBYTES_PER_ELEMENT, 3 * Float32Array.SBYTES_PER_ELEMENT);

		for (texture in group.textures) {

			GL.activeTexture (GL.TEXTURE0);
			GL.bindTexture (GL.TEXTURE_2D, texture);
			GL.enable (GL.TEXTURE_2D);

			GL.drawArrays (GL.TRIANGLE_STRIP, 0, 4);

		}

		var size = group.width * group.height;

        var result_rgba = new ByteArray (size*4);
        GL.readPixels (0, 0, group.width, group.height, GL.RGBA, GL.UNSIGNED_BYTE, result_rgba);

        var result_argb = new ByteArray (size*4);
		for (i in 0...size) {

			var r = result_rgba.readUnsignedByte ();
			var g = result_rgba.readUnsignedByte ();
			var b = result_rgba.readUnsignedByte ();
			var a = result_rgba.readUnsignedByte ();

			result_argb.writeByte (a);
			result_argb.writeByte (r);
			result_argb.writeByte (g);
			result_argb.writeByte (b);

		}
		result_argb.position = 0;

		var res = new BitmapData (group.width, group.height, true);
		res.setPixels (res.rect, result_argb);

		GL.bindFramebuffer (GL.FRAMEBUFFER, null);
		GL.bindBuffer (GL.ARRAY_BUFFER, null);
		GL.deleteProgram (program);

		return res;

	}

	public static function clean () : Void {

		GL.deleteRenderbuffer (fb_renderbuffer);
		GL.deleteFramebuffer (fb_framebuffer);
		GL.deleteTexture (fb_texture);

	}

}

enum UniformType {
	
	Int;
	Float;
	Int2;
	Float2;
	Int3;
	Float3;
	Int4;
	Float4;
	
}	

class LayerGroup {

	public var textures : Array<GLTexture>;
	public var width : Int;
	public var height : Int;
	public var buffer : GLBuffer;
	public var matrix : Float32Array;

	public function new (textures:Array<GLTexture>, width:Int, height:Int) {

		this.textures = textures;
		this.width = width;
		this.height = height;

		var data = [

			width, height, 0, 1, 1,
			0, height, 0, 0, 1,
			width, 0, 0, 1, 0,
			0, 0, 0, 0, 0

		];

		buffer = GL.createBuffer ();
		GL.bindBuffer (GL.ARRAY_BUFFER, buffer);
		GL.bufferData (GL.ARRAY_BUFFER, new Float32Array (cast data), GL.STATIC_DRAW);
		GL.bindBuffer (GL.ARRAY_BUFFER, null);

		var matrix_3d = Matrix3D.createOrtho (0, width, height, 0, -1000, 1000);
		matrix = Float32Array.fromMatrix (matrix_3d);

	}

	public function delete () : Void {

		for (texture in textures) {

			GL.deleteTexture (texture);

		}

		GL.deleteBuffer (buffer);

	}

}

/**
 * Modified lime.utils.GLUtils
 * The MIT License (MIT) Copyright (c) 2013-2014 OpenFL contributors
 */
class GLUtils {

	public static function compileShader (source:String, type:Int):GLShader {

		var shader = GL.createShader (type);
		GL.shaderSource (shader, source);
		GL.compileShader (shader);

		if (GL.getShaderParameter (shader, GL.COMPILE_STATUS) == 0) {

			switch (type) {

				case GL.VERTEX_SHADER: throw "Error compiling vertex shader";
				case GL.FRAGMENT_SHADER: throw "Error compiling fragment shader";
				default: throw "Error compiling unknown shader type";

			}

		}

		return shader;

	}

	public static function createProgram (vertexShader:GLShader, fragmentSource:String):GLProgram {

		var fragmentShader = compileShader (fragmentSource, GL.FRAGMENT_SHADER);

		var program = GL.createProgram ();
		GL.attachShader (program, vertexShader);
		GL.attachShader (program, fragmentShader);
		GL.linkProgram (program);

		if (GL.getProgramParameter (program, GL.LINK_STATUS) == 0) {

			throw "Unable to initialize the shader program.";

		}

		return program;

	}

}
