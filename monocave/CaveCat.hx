import lime.ui.Gamepad;
import input2action.Input2Action;
import lime.ui.KeyCode;
import lime.ui.GamepadButton;
import lime.ui.Window;
import input2action.ActionMap;
import input2action.ActionConfig;
import echo.Body;
import lime.graphics.Image;
import peote.view.Color;
import echo.World;
import ob.gum.backends.PeoteView;
import tyke.Graphics;
import tyke.Ldtk;
import tyke.Stage;
import tyke.Loop;

class CaveCat extends PhysicalStageLoop {
	var caves:Caves;

	public function new(assets:Assets) {
		super(assets);

		onInitComplete = begin;
	}

	function begin() {
		var controller = new Controller(gum.window);
		caves = new Caves(stage, assets, world, controller);
		alwaysDraw = true;
		gum.toggleUpdate(true);
	}

	override function onTick(tick:Int):Bool {
		caves.onTick();
		return super.onTick(tick);
	}
}

class Caves {
	var cat:Cat;
	var stage:Stage;
	var world:World;
	var controller:Controller;
	var tilePixelSize = 16;
	var visibleHeight = 100;
	var camStopAfter = 100;

	var camera:Camera;

	public function new(stage:Stage, assets:Assets, world:World, controller:Controller) {
		this.stage = stage;
		this.world = world;
		this.controller = controller;

		var monocaveSpriteSheet = assets.imageCache[0];
		var catSpriteSheet = assets.imageCache[1];
		var platformTiles = stage.createSpriteRendererLayer("monocave", monocaveSpriteSheet, tilePixelSize, false, false);
		var lightingRender = stage.createShapeRenderLayer("lightshapes", true, true);
		var echoDebugRender = stage.createShapeRenderLayer("echoDebugRender");

		var ldtk = new Monocave();
		var platformsTileMap = ldtk.levels[0].l_Platforms;
		var collisionMap = ldtk.levels[0].l_CollisionMap;
		var lightingMap = ldtk.levels[0].l_LightingMap;

		LevelLoader.renderLayer(platformsTileMap, (tileStack, cx, cy) -> {
			for (tileData in tileStack) {
				var tileX = cx * tilePixelSize;
				var tileY = cy * tilePixelSize;
				platformTiles.makeSprite(tileX, tileY, tilePixelSize, tileData.tileId);
			}
		});

		for (body in MapLoader.bodiesFromIntGrid(collisionMap)) {
			world.add(body);
			var shapeWidth = Std.int(body.shape.right - body.shape.left);
			var shapeHeight = Std.int(body.shape.bottom - body.shape.top);

			var color = Color.LIME;
			color.a = Globals.DebugAlphaLevel;

			echoDebugRender.makeShape(Std.int(body.x), Std.int(body.y), shapeWidth, shapeHeight, RECT, color);
		}

		var lights = [];
		for (body in MapLoader.bodiesFromIntGrid(lightingMap)) {
			var shapeWidth = 10;
			var shapeHeight = 16;
			
			var color = Color.CYAN;
			// light alpha is initaliiy 0 which is evaluated as whether the light is on or off
			color.a = 0;
			
			body.shape.solid = false;
			body.data.shape = lightingRender.makeShape(Std.int(body.x), Std.int(body.y) - 5, shapeWidth, shapeHeight, CIRCLE, color);
			world.add(body);
			lights.push(body);
		}

		camera = new Camera((x, y) -> {
			stage.setScroll(Std.int(x), Std.int(y));
		});

		initCat(catSpriteSheet, echoDebugRender, lightingRender);

		world.add(camera.body);

		// set 'global' listener (make sure things collide)
		world.listen();

		// set listener for cat and lights collision
		world.listen(cat.body, lights, {
			enter: (body1, body2, array) -> {
				// standard null protection
				if (body2.data.shape != null) {
					// let compiler know what Type shape is
					var shape:Shape = cast body2.data.shape;
					// if light is off
					if (shape.color.a == 0) {
						// make light on
						shape.color.a = 100;
						// give some indication that something just happened
						cat.pause();
					}
				}
			}
		});

		controller.registerPlayer(cat);
		
		initLightingShader();
	}

	public function onTick() {
		cat.onTick(1);
		if (cat.body.y > visibleHeight && camera.body.velocity.y == 0) {
			visibleHeight += 120;
			camera.body.velocity.y = -45;
		}
		var amountScrolled = camera.body.y * -1;

		if (amountScrolled > camStopAfter) {
			camStopAfter += camStopAfter;
			camera.body.velocity.y = 0;
		} else {
			if (cat.body.y > 640) {
				camera.body.y = 0;
				cat.body.x = 74;
				cat.body.y = 0;
				visibleHeight = 100;
				camStopAfter = 100;
				camera.body.velocity.y = 0;
			}
		}
	}

	function initCat(catSprites:Image, echoDebugRender:ShapeRenderer, lighting:ShapeRenderer) {
		var catTileSize = 32;
		var catBodySize = Std.int(catTileSize * 0.25);
		var catTiles = stage.createSpriteRendererLayer("catsprites", catSprites, catTileSize, false, true);

		var catSprite = catTiles.makeSprite(74, 10, catTileSize, 0);
		catSprite.shakeDistanceY = 0;
		catSprite.shakeDistanceX = 2.0;

		var catBody = new Body({
			mass: 1,
			x: catSprite.x,
			y: catSprite.y,
			max_velocity_x: 40, // slow speed for walking around
			max_velocity_y: 180, // faster for falling
			max_rotational_velocity: 0, // cat does not rotate, always lands on it's feet
			shape: {
				type: RECT,
				width: catBodySize,
				height: catBodySize,
				solid: true
			},
		});

		var color = Color.MAGENTA;
		color.a = Globals.DebugAlphaLevel;

		var catDebug = echoDebugRender.makeShape(Std.int(catBody.x), Std.int(catBody.y), catBodySize, catBodySize, RECT, color);

		var spriteSheetColumns = 8;
		var animation = new Animation(spriteSheetColumns);

		animation.defineFrames(IDLE_FRONT, 0, 0, 4);
		animation.defineFrames(IDLE_SIDE, 1, 0, 4);
		animation.defineFrames(IDLE_LICK, 2, 0, 4);
		animation.defineFrames(IDLE_PAW, 3, 0, 4);
		animation.defineFrames(WALK, 4, 0, 8);
		animation.defineFrames(RUN, 5, 0, 8);
		animation.defineFrames(IDLE_SLEEP, 6, 0, 4);
		animation.defineFrames(ACTION, 7, 0, 6);
		animation.defineFrames(POUNCE, 8, 0, 7);
		animation.defineFrames(TAUNT, 9, 0, 8);

		animation.setAnimation(IDLE_FRONT);

		var lightColor:Color = Color.WHITE;
		// lightColor.a = 40;
		var catLight = lighting.makeShape(Std.int(catSprite.x), Std.int(catSprite.y), 30, 30, CIRCLE, lightColor);
		cat = new Cat(catTileSize, catBodySize, catSprite, catBody, catDebug, catLight, animation);
		catBody.sprite = catSprite;
		world.add(catBody);
	}

	function initLightingShader() {
		stage.program.addTexture(stage.getLayer("lightshapes").frameBuffer.texture, "lights");
		stage.program.addTexture( stage.getLayer("catsprites").frameBuffer.texture, "entities");
		stage.program.addTexture( stage.getLayer("monocave").frameBuffer.texture, "paintable");

		stage.globalFilter("globalCompose(globalFramebuffer_ID, entities_ID, lights_ID, paintable_ID)", "
			
			vec3 platformDark = vec3(0.033, 0.025, 0.015);
			vec3 darkness = vec3(0.06);
			vec4 fragColor = vec4(1.0, 0.0, 0.0, 1.0);

			vec4 globalCompose(int sumID, int entitiesID, int lightsID, int paintableID )
			{
				vec4 catColor = getTextureColor(entitiesID, vTexCoord);
				
				if(catColor.a == 0.0){
					// if alpha on cat 0 is then we are drawing the background

					vec4 platformColor = getTextureColor(paintableID, vTexCoord);
					vec4 lightColor = getTextureColor(lightsID, vTexCoord);

					// set initial color of level tiles
					platformColor.rgb = platformDark;

					if(lightColor.a > 0.0){

						// if the light is lit, put the color on the level tiles
						platformColor.rgb = mix(lightColor.rgb, darkness, 0.8);
					}
					else{

						// else the light is off, make platforms darker
						platformColor.rgb = mix(lightColor.rgb, platformDark, 0.8);
					}
					
					// set return color from platform
					fragColor = platformColor;
				}
				else{

					// else cat alpha was > 0 then set color from cat
					fragColor = catColor;
				}
				
				return fragColor;
			}
		");
	}

}

class Cat {
	var tileSize:Int;
	var sprite:Sprite;
	var animation:Animation;
	var animationCountdown:CountDownInt;
	var ticksPerAnimationFrame:Int;
	var idleCountdown:CountDownInt;
	var echoDebugRender:Shape;
	var light:Shape;
	var bodySize:Int;
	var defaultLightSize:Int;

	public var body(default, null):Body;

	public function new(tileSize:Int, bodySize:Int, sprite:Sprite, body:Body, echoDebugRender:Shape, light:Shape, animation:Animation) {
		this.tileSize = tileSize;
		this.bodySize = bodySize;
		this.sprite = sprite;
		this.echoDebugRender = echoDebugRender;
		this.light = light;
		this.defaultLightSize = light.w;
		this.body = body;
		this.animation = animation;
		ticksPerAnimationFrame = 6;
		animationCountdown = new CountDownInt(ticksPerAnimationFrame, () -> animate(), true);
		idleCountdown = new CountDownInt(60, () -> setIdle(), true);
		canWalk = true;
		this.body.on_move = (x, y) -> {
			this.sprite.move(x, y - 10);
			this.echoDebugRender.setPosition(x, y);
			this.light.setPosition(x, y);
		};
	}

	public function onTick(elapsedTicks:Int) {
		idleCountdown.update(elapsedTicks);
		animationCountdown.update(elapsedTicks);
	}

	function animate() {
		if(body.velocity.y > 0){
			animation.setAnimation(IDLE_FRONT);
		}
		sprite.tile = animation.currentTile();
		animation.advance();
		// todo - separate layer for temporary light?
		// currently there is no real feeling of the cat providing the light
		// as there is no contrast betwee where it is now and where it has been
		if (animation.currentAnimation == IDLE_SLEEP) {
			if (lightIsDefaultSize())
				resizeLight(16);
		} else {
			if (!lightIsDefaultSize()) {
				resizeLight(defaultLightSize);
			}
		}
	}

	inline function lightIsDefaultSize():Bool {
		return defaultLightSize == light.w;
	}

	function resizeLight(newSize:Int) {
		light.h = newSize;
		light.w = newSize;
	}

	function setIdle() {
		if (body.velocity.x == 0 && body.velocity.y == 0) {
			animationCountdown.changeDuration(Std.int(ticksPerAnimationFrame * 4));
			animation.setAnimation(IDLE_SLEEP);
			animate();
		}
		canWalk = true;
	}
	
	public function pause() {
		idleCountdown.restart();
		animation.setAnimation(IDLE_LICK);
		// animation.setAnimation(IDLE_PAW);
		animate();
		
		body.velocity.x = 0;
		canWalk = false;
	}

	function walk(direction:Int){
		idleCountdown.restart();
		sprite.flipX(direction < 0);
		body.velocity.x += speed * direction;
		animationCountdown.changeDuration(ticksPerAnimationFrame);
		animation.setAnimation(WALK);
		animate();
	}

	function stopWalking(){
		if(body.velocity.x != 0){
			idleCountdown.restart();
			animation.setAnimation(IDLE_SIDE);
			// animate();
			body.velocity.x = 0;
		}
	}

	function wake() {
		idleCountdown.restart();
		animation.setAnimation(IDLE_FRONT);
		animate();
	}

	var canWalk:Bool;

	public function controlLeft(isDown:Bool) {
		if(!canWalk)
			return;

		if (isDown)
			walk(-1);
		else
			stopWalking();
	}

	var speed = 25;

	public function controlRight(isDown:Bool) {
		if(!canWalk)
			return;

		if (isDown)
			walk(1);
		else
			stopWalking();
	}

	public function controlUp(isDown:Bool) {
		if (isDown && body.velocity.x == 0)
			wake();
	}

	public function controlDown(isDown:Bool) {}

	public function controlAction(isDown:Bool) {
		trace('v ${body.velocity.x} a ${body.acceleration.x} x ${sprite.x} y ${sprite.y}');
	}


}

@:enum abstract AnimationKey(Int) from Int to Int {
	var IDLE_FRONT;
	var IDLE_SIDE;
	var IDLE_LICK;
	var IDLE_PAW;
	var WALK;
	var RUN;
	var IDLE_SLEEP;
	var ACTION;
	var POUNCE;
	var TAUNT;
}

class Controller {
	var actionConfig:ActionConfig;
	var actionMap:ActionMap;
	var players:Array<Cat> = [];

	public function new(window:Window) {
		actionConfig = [
			{
				gamepad: GamepadButton.DPAD_LEFT,
				keyboard: KeyCode.LEFT,
				action: "left"
			},
			{
				gamepad: GamepadButton.DPAD_RIGHT,
				keyboard: KeyCode.RIGHT,
				action: "right"
			},
			{
				gamepad: GamepadButton.DPAD_UP,
				keyboard: KeyCode.UP,
				action: "up"
			},
			{
				gamepad: GamepadButton.DPAD_DOWN,
				keyboard: KeyCode.DOWN,
				action: "down"
			},
			{
				gamepad: GamepadButton.B,
				keyboard: KeyCode.LEFT_SHIFT,
				action: "action"
			},
		];

		actionMap = [
			"left" => {
				action: (isDown, player) -> {
					players[player].controlLeft(isDown);
				},
				up: true
			},
			"right" => {
				action: (isDown, player) -> {
					players[player].controlRight(isDown);
				},
				up: true
			},
			"up" => {
				action: (isDown, player) -> {
					players[player].controlUp(isDown);
				},
				up: true
			},
			"down" => {
				action: (isDown, player) -> {
					players[player].controlDown(isDown);
				},
				up: true
			},
			"action" => {
				action: (isDown, player) -> {
					players[player].controlAction(isDown);
				},
				up: true
			},
		];

		var input2Action = new Input2Action(actionConfig, actionMap);
		input2Action.setKeyboard();

		// event handler for new plugged gamepads
		input2Action.onGamepadConnect = function(gamepad:Gamepad) {
			trace('player gamepad connected');
			input2Action.setGamepad(gamepad);
		}

		input2Action.onGamepadDisconnect = function(player:Int) {
			trace('players $player gamepad disconnected');
		}

		input2Action.enable(window);
	}

	public function registerPlayer(player:Cat) {
		players.push(player);
	}
}

class Globals {
	public static var DebugAlphaLevel:Int = 0;
}
