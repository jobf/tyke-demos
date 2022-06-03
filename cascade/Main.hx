// package cascade;
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
			displayHeight: 496,
			displayIsScaled: true
		});

		var config:tyke.Glyph.GlyphLoopConfig = {
			numCellsWide: 40,
			numCellsHigh: 40,
		}

        var assets = new Assets({
            fonts: [
                "assets/fonts/tiled/hack_ascii.json"
            ],
            images: [
            ]
        });

		gum.changeLoop(new Cascade(config, assets));
	}
}
