
import echo.data.Types.ShapeType;
import echo.Body;
import echo.World;
import ob.gum.backends.PeoteView;
import tyke.Loop;
import tyke.Glyph;
import tyke.Graphics;
import tyke.Echo;
import tyke.Stage;

class Shapes extends PhysicalStageLoop {
	var shapes:ShapeShaker;

	public function new(assets:Assets) {
		super(assets);
		onInitComplete = () -> {
			initWorldAndStage();
			begin();
		}
		
		// keyboard.bind(KeyCode.P, "PAUSE", "TOGGLE UPDATE", loop -> {
			// 	gum.toggleUpdate();
			// });
		}
		
		function begin() {
		shapes = new ShapeShaker(world, stage);
		debug = new EchoDebug(stage.createRectangleRenderLayer("rectangles"));
		world.listen();
		alwaysDraw = true;
		gum.toggleUpdate(true);
	}

	override function onTick(deltaMs:Int):Bool {
		shapes.onTick(deltaMs);
		var requestDraw = super.onTick(deltaMs);
		return requestDraw;
	}

	override function onDraw(deltaMs:Int) {
		super.onDraw(deltaMs);
		
		debug.draw(world);
	}

	override function onMouseMove(x:Float, y:Float) {
		super.onMouseMove(x, y);
		if (shapes != null) {
			shapes.onMouseMove(x, y);
		}
	}

	var debug:EchoDebug;
}

class ShapeShaker {
	var stage:Stage;
	var world:World;
	var shapesLayer:ShapeRenderer;

	public function new(world:World, stage:Stage) {
		this.world = world;
		this.stage = stage;
		shapesLayer = this.stage.createShapeRenderLayer("shapes");

		mouseBody = new HardLight({
			x: stage.width * 0.5,
			y: stage.height * 0.5,
			kinematic: true,
			rotational_velocity: 10,
			shape: {
				type: POLYGON,
				sides: 3,
				radius: 100,
				width: 200,
				height: 200,
				solid: true
			}
		}, this.world, shapesLayer, 0x44ff44aa);
		// var p:Polygon = cast mouseBody.body.shape;
		// var a = p.vertices[0].distance(p.vertices[1]);

		var blockBody = new HardLight({
			mass: 0,
			elasticity: 0.3,
			x: stage.width * 0.5,
			y: stage.height * 0.5,
			shape: {
				type: RECT,
				width: stage.width * 0.3,
				height: stage.height * 0.03,
			}
		}, this.world, shapesLayer, 0xffff4455);
		
		world.listen({
			// separate: separate,
			enter: (body1:Body, body2:Body, array) -> {
				// if(body1.element != null){}
				// body1.hardlight.collide(body1, body2, array);
				// body2.hardlight.collide(body1, body2, array);
			},
			// stay: stay,
			// exit: exit,
			// condition: condition,
			// percent_correction: percent_correction,
			// correction_threshold: correction_threshold
		});
	}

	var elapsedTicks:Int = 0;
	var body_count = 16;
	var timer = 0;

	var polygonSides:Array<Int> = [3, 3, 3, 3, 5, 7, 11];

	public function onTick(deltaMs:Int):Void {
		elapsedTicks++;
		timer += deltaMs;
		if (timer > 360) {
			var size = randomFloat(68, 102);
			var isSolid = randomChance();
			if (world.count < body_count) {
				var shapeType:ShapeType = randomChance() ? RECT : randomChance() ? POLYGON : CIRCLE;
				var color = isSolid ? 0xffffff99 : 0x4444ff99;
				if (shapeType == POLYGON && !isSolid) {
					color = 0xff33ff99;
				}
				var numSides = 1;
				if (shapeType != CIRCLE) {
					if (shapeType == POLYGON) {
						var i = randomInt(polygonSides.length - 1);
						numSides = polygonSides[i];
					} else {
						// RECT
						numSides = 4;
					}
				}
				var light = new HardLight({
					x: randomFloat(0, world.width),
					y: 100,
					velocity_y: 20,
					mass: 4,
					elasticity: 0.3,
					rotational_velocity: randomFloat(-30, 30),
					shape: {
						type: shapeType,
						radius: size * 0.5,
						width: size,
						height: size,
						solid: isSolid,
						sides: numSides, // todo better shader drawing of shapes -- Random.range_int(3, 8)
					}
				}, world, shapesLayer, color);
			}

			timer = 0;
		}
		world.for_each((member) -> {
			if (isOutOfBounds(member)) {
				member.velocity.set(0, 0);
				member.set_position(randomFloat(0, world.width), 0);
			}
		});
	}

	public function onMouseMove(x:Float, y:Float) {
		mouseBody.body.set_position(x, y);
	}

	function isOutOfBounds(b:Body) {
		var bounds = b.bounds();
		var check = bounds.min_y > world.height || bounds.max_x < 0 || bounds.min_x > world.width;
		bounds.put();
		return check;
	}

	var mouseBody:HardLight;

}

@:structInit
class Range {
	public var min:Int;
	public var max:Int;
}

class Emitter {
	var isEmitting:Bool;
	var rateLimit:Float;
	var timer:Float;
	var onEmit:Float->Void;

	public function new(onEmit:Float->Void, isEmitting:Bool = true, rateLimit:Float = 0) {
		this.onEmit = onEmit;
		this.isEmitting = isEmitting;
		this.rateLimit = rateLimit;
		this.timer = 0;
	}

	public function update(deltaMs:Float):Void {
		if (isEmitting) {
			timer += deltaMs;
			if (timer > rateLimit) {
				onEmit(deltaMs);
				timer = 0;
			}
		}
	}
}
