import ob.gum.backends.PeoteView;
import ob.gum.Core;
import lime.ui.Window;
import ob.gum.backends.Lime;

class Main extends App {
	override function init(window:Window, ?config:GumConfig) {
		super.init(window, {
			framesPerSecond: 30,
			drawOnlyWhenRequested: true,
			displayWidth: 800,
			displayHeight: 600,
			displayIsScaled: true
		});

		var glyphsConfig:tyke.Glyph.GlyphLoopConfig = {
			numCellsWide: Std.int(800 / 16),
			numCellsHigh: Std.int(600 / 16),
		}

        var assets = new Assets({
            fonts: [
				"assets/fonts/tiled/hack_ascii.json"
            ],
            images: [
				"assets/images/bit-bonanza-food.png",
            ]
        });

		gum.changeLoop(new TYKE(glyphsConfig, assets));
	}
}
