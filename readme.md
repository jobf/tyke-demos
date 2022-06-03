# tyke demos

This repository contains a collection of demo projects built with tyke - https://github.com/jobf/tyke

## Feature demos

Mostly testing out parts of the API.

### glyph manipulation, sprites, physics, shaders

https://jobf.github.io/tyke-demos/

### glyph manipulation

https://jobf.github.io/tyke-demos/glyphs/

### physics

https://jobf.github.io/tyke-demos/shapes/

## Game demos

More fully featured demos.

### glyph based game

https://jobf.github.io/tyke-demos/cascade/


### sprite based game

https://jobf.github.io/tyke-demos/monocave/

## Run Locally

To run the samples locally first set up tyke as documented here - https://github.com/jobf/tyke

Then you can run a demo from a directory, for example

```shell
# change working directory
cd shapes

# hashlink 
lime test hl

# html5
lime test html5

# =^.^=
lime test neko
```

### Scripts

Each demo has scripts as described below

`hl-run` - runs the demo in hashlink

`web-debug` - generate a debug html5 build including source maps and start local web server (chromium browser recommended for viewing)

`web-release` - generate a final html5 build and zip the contents ready for distribution