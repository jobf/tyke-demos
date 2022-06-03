import lime.graphics.Image;
import peote.text.Font;
import lime.ui.KeyCode;
import ob.gum.backends.PeoteView;
import echo.data.Options.BodyOptions;
import tyke.Palettes.Sixteen;
import echo.Body;
import echo.World;
import tyke.Layers;
import tyke.Loop;
import tyke.Glyph;
import tyke.Stage;
import tyke.Graphics;
using ob.gum.backends.PeoteView.PaletteExtensions;

/** 
	TYKE extends PhysicalStageLoop which provides graphics and arcade physics.
	Here is the setup logic for the whole scene.
**/
class TYKE extends PhysicalStageLoop {
	var salad:SimulationSalad;
	var soup:WordSoup;

	public function new(data:GlyphLoopConfig, assets:Assets) {
		// pass the assets to the super class to which will attempt to load them and set up graphics and physics
		super(assets);

		// called when assets etc are ready
		onInitComplete = () -> {
			setupBackgroundLayer();

			var totalColumns = Math.ceil(stage.width / assets.fontCache[0].config.width);
			var totalRows = Math.ceil(stage.height / assets.fontCache[0].config.height);

			// setup flashing glyphs logic
			soup = new WordSoup(totalColumns, totalRows, stage, assets.fontCache[0]);

			// setup bouncing fruit logic logic
			salad = new SimulationSalad(world, stage, assets.imageCache[0]);

			// todo - fix this
			// setupCurtainLayer();

			// inspired by https://www.shadertoy.com/view/4sBBDK
			final dotScreenShader = '
			float greyScale(in vec3 col) {
				return dot(col, vec3(0.2126, 0.7152, 0.0722));
			}

			mat2 rotate2d(float angle){
				return mat2(cos(angle), -sin(angle), sin(angle),cos(angle));
			}

			float dotScreen(in vec2 uv, in float angle, in float scale, vec2 res) {
				float s = sin( angle ), c = cos( angle );
				vec2 p = (uv - vec2(0.5)) * res.xy;
				vec2 q = rotate2d(angle) * p * scale; 
				return ( sin( q.x ) * sin( q.y ) ) * 4.0;
			}
			
			vec4 globalCompose( int textureID ){
				vec2 uv = vTexCoord;
				vec3 col = getTextureColor(textureID, vTexCoord).rgb; 
				float grey = greyScale(col); 
				float angle = 0.4;
				float scale = 1.0 + 0.8 * sin(uTime); 
				vec2 res = getTextureResolution(textureID);
				col = vec3( grey * 10.0 - 5.0 + dotScreen(uv, angle, scale, res ) );
				vec3 tex = getTextureColor(textureID, vTexCoord).rgb;
				return vec4( mix(col, tex, 0.9), 1.0 );
			}
			';

			// set up shader on the global framebuffer
			stage.globalFilter("globalCompose(globalFramebuffer_ID)", dotScreenShader);

			// by default the graphics buffers draw when called manually
			// settign alwaysDraw will draw every frame
			alwaysDraw = true;

			// start the game loop
			gum.toggleUpdate(true);
		}

		// bind a keyboard letter to a function
		keyboard.bind(KeyCode.P, "PAUSE", "TOGGLE UPDATE", loop -> {
			gum.toggleUpdate();
		});
	}

	override function onTick(deltaMs:Int):Bool {
		// update the glyphs
		soup.onTick(deltaMs);

		// update the fruit
		salad.onTick(deltaMs);

		return alwaysDraw;
	}

	function setupBackgroundLayer() {
		final injectTimeUniform = true;
		var hues = new Filter(stage.width, stage.height, ColorFilterFormulas.Hues, injectTimeUniform);
		var isLayerPersistent = false;
		var bgLayer = stage.createLayer("bg", isLayerPersistent);
		hues.addToDisplay(bgLayer.display);
	}

	function setupForegroundLayer() {
		// this filter should appear as separate layer with 'frameBuffer' behind it
		// that was possible when all layers had their own texture being mixed
		// currently does not work
		var useGlobalFrameBuffer = false;
		var curtainLayer = stage.createLayer("curtain", useGlobalFrameBuffer);
		var curtainFilter = new Filter(stage.width, stage.height, ColorFilterFormulas.Gradient);
		curtainFilter.addToDisplay(curtainLayer.display);
	}
}

/**
	This class handles writing text to the Glyph Layer in variations
**/
class WordSoup {
	var glyphs:GlyphGrid;
	var glyphRender:GlyphRenderer;

	public function new(numColumns:Int, numRows:Int, stage:Stage, font:Font<FontStyle>) {
		// set up layer used for rendering the glyphs
		glyphRender = stage.createGlyphRendererLayer("wordSoup", font);

		var glyphWidth = glyphRender.fontProgram.fontStyle.width;
		var glyphHeight = glyphRender.fontProgram.fontStyle.height;

		// the configuration for a grid of glyphs
		var config:GlyphGridConfig = {
			numColumns: numColumns,
			numRows: numRows,
			cellWidth: Math.ceil(glyphWidth),
			cellHeight: Math.ceil(glyphHeight),
			palette: new Palette(Sixteen.Versitle.toRGBA()),

			// the cellInit function is run on every cell in the grid to initialise it
			cellInit: (col, row) -> {
				// pick a random character from the word for the glyph
				var charIndex = randomInt(word.length) - 1;
				var charCode = word.charCodeAt(charIndex);

				// determine pixel position to render glyph at
				var x = col * glyphWidth;
				var y = row * glyphHeight;

				// render the glyph
				var renderedGlyph = glyphRender.fontProgram.createGlyph(charCode, x, y, glyphRender.fontProgram.fontStyle);

				// return cell configuration
				return {
					char: charCode,
					glyph: renderedGlyph,
					paletteIndexFg: 4,
					paletteIndexBg: -1,
					bgIntensity: 1.0,
				}
			}
		}

		// set up the grid
		glyphs = new GlyphGrid(config, glyphRender.fontProgram);
	}

	var word:String = "TYKE";
	var waves = 2;
	var gain = 0.02;
	var elapsedTicks:Int = 0;

	public function onTick(deltaMs:Int):Void {
		// update counter used for sin calculation
		elapsedTicks++;

		// run function on every cell in the grid
		glyphs.forEach((column, row, cell) -> {
			// next color for each glyph is determined by factor of time and position
			var R = 0.5 + 0.5 * Math.cos(elapsedTicks + column + 0);
			var G = 0.5 + 0.5 * Math.cos(elapsedTicks + row + 2);
			var B = 0.5 + 0.5 * Math.cos(elapsedTicks + column + 4);
			var A = Math.sin(column - row * waves * elapsedTicks * gain);
			cell.glyph.color.r = Math.ceil(255 * R);
			cell.glyph.color.g = Math.ceil(255 * G);
			cell.glyph.color.b = Math.ceil(255 * B);
			cell.glyph.color.alpha = Math.ceil((127 * A) + 127);

			// next character is determined by factor of time and position
			var CI = 0.5 + 0.5 * Math.sin((elapsedTicks * 0.3) + column + 4);
			var charIndex = Math.ceil(CI * (word.length)) - 1;

			// update the cell data
			cell.char = word.charCodeAt(charIndex);

			// update the rendered glyph
			glyphRender.fontProgram.glyphSetChar(cell.glyph, cell.char);
		});
	}
}

class SimulationSalad {
	var stage:Stage;
	var world:World;
	var sprites:Array<Sprite>;
	var spriteFrames:SpriteRenderer;
	final frameSize:Int = 10;
	var debugLayer:ShapeRenderer;

	public function new(world:World, stage:Stage, spriteSheet:Image) {
		this.world = world;
		this.stage = stage;
		this.sprites = [];
		initSprites(spriteSheet);
		initEdges();
		initCollisionListeners();
	}

	function initSprites(spriteSheet:Image) {
		spriteFrames = stage.createSpriteRendererLayer("fruitSprites", spriteSheet, frameSize);
		debugLayer = stage.createShapeRenderLayer("echo");
	}

	function initEdges() {
		var edgeThickness = 40;
		// top
		makeEdge(Std.int(stage.width * 0.5), 0, stage.width + (edgeThickness * 2), edgeThickness);
		// bottom
		makeEdge(Std.int(stage.width * 0.5), stage.height, stage.width + (edgeThickness * 2), edgeThickness);
		// left
		makeEdge(edgeThickness - Std.int(edgeThickness * 0.5), Std.int(stage.height * 0.5), edgeThickness, stage.height + (edgeThickness * 2));
		// right
		// makeEdge(stage.width + Std.int(edgeThickness * 0.5), Std.int(stage.height * 0.5), edgeThickness, stage.height + (edgeThickness * 2));
	}

	function makeEdge(x:Int, y:Int, w:Int, h:Int) {
		var options:BodyOptions = {
			shape: {
				type: RECT,
				width: w,
				height: h
			},
			mass: 0, // mass of 0 is unmovable
			x: x,
			y: y,
			elasticity: 2.0,
		};
		var body = world.make(options);
		final debug = false;

		if (debug) {
			var d = debugLayer.makeShape(x, y, w, h, RECT);
		}
	}

	function initCollisionListeners() {
		final minTileIndex = 4;
		final maxTileIndex = 34 - minTileIndex;

		world.listen({
			enter: (body1:Body, body2:Body, array) -> {
				// trace('$body1 $body2');
				if (body1.sprite != null) {
					// set random frame from sprite sheet
					body1.sprite.tile = randomInt(maxTileIndex) + minTileIndex;
					// if it's not already rotating, or if chance is true, increase rotation clockwise
					if (body1.rotational_velocity != 0 || randomChance()) {
						var minRotation = body1.mass * 10;
						body1.rotational_velocity -= randomFloat(minRotation, minRotation + 10);
					}
					// if colliding with another sprite, spritesheet frame 'rubs off'
					if (body2.sprite != null) {
						body2.sprite.tile = body1.sprite.tile;
					}
				}
			}
		});
	}

	var timer = 0;
	var colliders:Array<Body> = [];

	public function onTick(deltaMs:Int) {
		for (c in colliders) {
			if (c.x > stage.width + 100) {
				c.active = false;
				// todo recycle bodies/sprites
			}
		}
		final wait = 750 - randomInt(300);
		timer += deltaMs;
		if (timer > wait) {
			var collider = makeCollider(50, 50);
			colliders.push(collider);
			launch(world.add(collider), world, false);
			timer = 0;
		}
	}

	inline function launch(b:Body, w:World, left:Bool) {
		b.set_position(left ? 20 : w.width - 20, w.height / 2);
		var velocityX = -3000;
		var velocityY = 3000;
		b.velocity.set(velocityX, velocityY);
	}

	final spriteScale:Int = 3;

	inline function attachSprite(body:Body, options:BodyOptions, tileIndex:Int = 0):Sprite {
		var sprite:Sprite = spriteFrames.makeSprite(-100, -100, Std.int(options.shape.width * spriteScale), tileIndex);
		body.on_move = (x, y) -> {
			sprite.move(x, y);
			// sprite.x = x;
			// sprite.y = y;
		};

		body.on_rotate = rotation -> {
			sprite.rotate(rotation);
			// sprite.rotation = rotation;
		};

		body.sprite = sprite;
		final debug = false;
		if (debug) {
			var x = Std.int(options.x);
			var y = Std.int(options.y);
			var w = Std.int(options.shape.width);
			var h = Std.int(options.shape.height);
			sprite.attachDebug(debugLayer.makeShape(x, y, w, h, RECT));
		}
		return sprite;
	}

	inline function makeCollider(width:Int, height):Body {
		var options:BodyOptions = {
			elasticity: 0.5,
			mass: 10 - randomInt(5),
			x: -100,
			y: -100,
			max_velocity_x: 900,
			max_velocity_y: 900,
			max_rotational_velocity: 200,
			shape: {
				type: RECT,
				width: width,
				height: height
			},
		};
		var body = new Body(options);
		var sprite:Sprite = attachSprite(body, options, 4);
		sprite.c.alpha = Math.ceil(95 * (5 / body.mass)) + 160;
		sprites.push(sprite);
		return body;
	}
}

class ColorFilterFormulas {
	public static var White = '
	vec4 solidColor = vec4(0.03);
	vec4 compose(){
		return solidColor;
	}
	';
	
	public static var Hues = '
	vec4 compose(){
		// time varying pixel color
		vec3 col = 0.5 + 0.5*cos(uTime+vTexCoord.xyx+vec3(0,2,4));
		return vec4(col * 0.5, 0.5);
	}
	';

	public static var Gradient = '
	vec4 compose(){
		// y varying pixel alpha
		float fmin = 0.3;
		float fmod = mod(vTexCoord.y, 2.0);
		float fstep = fmin + (1.0 - fmin) * fmod;
		return vec4(1.0, 1.0, 1.0, fstep);
	}
	';
}