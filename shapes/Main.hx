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

        var assets = new Assets({
            fonts: [
            ],
            images: [
            ]
        });

		gum.changeLoop(new Shapes(assets));
	}
}
