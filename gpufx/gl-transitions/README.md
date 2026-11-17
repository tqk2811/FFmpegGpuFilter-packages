# gl-transitions

GPU ports of transitions from [gl-transitions](https://github.com/gl-transitions/gl-transitions). Each package is a `progress` (0 to 1) driven transition between two clips of the same size. The GLSL of each original is rewritten in WGSL, keeping its coordinates (y up) and its look; at `progress` 0 and 1 the packages show the exact clips. Parameters that are points (`center`) are given y down, as in the other gpufx packages.

Licenses: every original here is MIT except `InvertedPageCurl.glsl` (BSD 3-Clause, Hewlett-Packard). The texts and the author of each file are in [LICENSE](LICENSE).

| Package | Original file | Author | License |
| --- | --- | --- | --- |
| [cube](cube/README.md) | [Cube.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Cube.glsl) | gre | MIT |
| [pagecurl](pagecurl/README.md) | [InvertedPageCurl.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/InvertedPageCurl.glsl) | Hewlett-Packard | BSD 3-Clause |
| [ripple](ripple/README.md) | [Ripple.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Ripple.glsl) | gre | MIT |
| [swirl](swirl/README.md) | [Swirl.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Swirl.glsl) | Sergey Kosarevsky | MIT |
| [doorway](doorway/README.md) | [Doorway.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Doorway.glsl) | gre | MIT |
| [burn](burn/README.md) | [BurnThrough.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BurnThrough.glsl) | liubailin2020@gmail.com | MIT |
| [crosswarp](crosswarp/README.md) | [CrossWarp.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CrossWarp.glsl) | Eke Péter | MIT |
| [crosszoom](crosszoom/README.md) | [CrossZoom.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CrossZoom.glsl) | rectalogic | MIT |
| [dreamy](dreamy/README.md) | [Dreamy.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Dreamy.glsl) | mikolalysenko | MIT |
| [kaleidoscope](kaleidoscope/README.md) | [Kaleidoscope.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Kaleidoscope.glsl) | nwoeanhinnogaehr | MIT |
| [glitch-displace](glitch-displace/README.md) | [GlitchDisplace.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitchDisplace.glsl) | Matt DesLauriers | MIT |
| [morph](morph/README.md) | [Morph.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Morph.glsl) | paniq | MIT |
| [mosaic](mosaic/README.md) | [Mosaic.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Mosaic.glsl) | Xaychru | MIT |
| [polar-function](polar-function/README.md) | [FlowerWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FlowerWipe.glsl) (formerly `polar_function.glsl`) | Fernando Kuteken | MIT |
| [squeeze](squeeze/README.md) | [Squeeze.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Squeeze.glsl) | gre | MIT |
| [heart](heart/README.md) | [HeartWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HeartWipe.glsl) | gre | MIT |
| [bounce](bounce/README.md) | [Bounce.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Bounce.glsl) | Adrian Purser | MIT |
| [film-burn](film-burn/README.md) | [FilmBurn.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FilmBurn.glsl) | Anastasia Dunbar | MIT |

Not ported because an existing package already does the same:

- `RadialWipe.glsl` (Radial): the `radial` mode of [xfade](../ffmpeg/xfade/README.md) and [clock-wipe](../tqk2811/TqkLibrary.FFmpegTransition/clock-wipe/README.md).
- `WindowSlices.glsl` (windowslice): the `hlslice` mode of [xfade](../ffmpeg/xfade/README.md).
