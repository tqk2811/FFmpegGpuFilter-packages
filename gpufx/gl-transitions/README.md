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
| [butterfly-wave-scrawler](butterfly-wave-scrawler/README.md) | [ButterflyWaveScrawler.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ButterflyWaveScrawler.glsl) | mandubian | MIT |
| [color-distance](color-distance/README.md) | [ColorDistance.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ColorDistance.glsl) | P-Seebauer | MIT |
| [color-phase](color-phase/README.md) | [ColorPhase.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ColorPhase.glsl) | gre | MIT |
| [crazy-parametric-fun](crazy-parametric-fun/README.md) | [CrazyParametricFun.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CrazyParametricFun.glsl) | mandubian | MIT |
| [crosshatch](crosshatch/README.md) | [Crosshatch.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Crosshatch.glsl) | pthrasher | MIT |
| [directional-warp](directional-warp/README.md) | [DirectionalWarp.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DirectionalWarp.glsl) | pschroen | MIT |
| [fly-eye](fly-eye/README.md) | [FlyEye.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FlyEye.glsl) | gre | MIT |
| [glitch-memories](glitch-memories/README.md) | [GlitchMemories.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitchMemories.glsl) | Gunnar Roth (based on work by natewave) | MIT |
| [multiply-blend](multiply-blend/README.md) | [MultiplyBlend.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/MultiplyBlend.glsl) | Fernando Kuteken | MIT |
| [pinwheel](pinwheel/README.md) | [Pinwheel.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Pinwheel.glsl) | Mr Speaker | MIT |
| [polka-dots-curtain](polka-dots-curtain/README.md) | [PolkaDotsCurtain.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PolkaDotsCurtain.glsl) | bobylito | MIT |
| [random-squares](random-squares/README.md) | [RandomSquares.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RandomSquares.glsl) | gre | MIT |
| [window-blinds](window-blinds/README.md) | [WindowBlinds.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WindowBlinds.glsl) | Fabien Benetou | MIT |
| [squares-wipe](squares-wipe/README.md) | [SquaresWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SquaresWipe.glsl) | gre | MIT |
| [bowtie](bowtie/README.md) | [BowTie.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BowTie.glsl) | KMojek | MIT |
| [bowtie-horizontal](bowtie-horizontal/README.md) | [BowTieHorizontal.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BowTieHorizontal.glsl) | huynx | MIT |
| [doom-melt](doom-melt/README.md) | [DoomMelt.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DoomMelt.glsl) | Zeh Fernando | MIT |
| [dreamy-zoom](dreamy-zoom/README.md) | [DreamyZoom.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DreamyZoom.glsl) | Zeh Fernando | MIT |
| [hexagonalize](hexagonalize/README.md) | [Hexagonalize.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Hexagonalize.glsl) | Fernando Kuteken | MIT |
| [perlin](perlin/README.md) | [PerlinDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PerlinDissolve.glsl) | Rich Harris | MIT |
| [rotate-scale-fade](rotate-scale-fade/README.md) | [RotateScaleFade.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RotateScaleFade.glsl) | Fernando Kuteken | MIT |
| [rolls](rolls/README.md) | [Rolls.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Rolls.glsl) | Mark Craig | MIT |
| [swap](swap/README.md) | [Swap.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Swap.glsl) | gre | MIT |
| [tv-static](tv-static/README.md) | [TvStatic.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TvStatic.glsl) | Brandon Anzaldi | MIT |
| [undulating-burn-out](undulating-burn-out/README.md) | [UndulatingBurnOut.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/UndulatingBurnOut.glsl) | pthrasher | MIT |
| [water-drop](water-drop/README.md) | [WaterDrop.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WaterDrop.glsl) | Paweł Płóciennik | MIT |
| [zoom-in-circles](zoom-in-circles/README.md) | [ZoomInCircles.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ZoomInCircles.glsl) | dycm8009 | MIT |

Not ported because an existing package already does the same:

- `RadialWipe.glsl` (Radial): the `radial` mode of [xfade](../ffmpeg/xfade/README.md) and [clock-wipe](../tqk2811/TqkLibrary.FFmpegTransition/clock-wipe/README.md).
- `WindowSlices.glsl` (windowslice): the `hlslice` mode of [xfade](../ffmpeg/xfade/README.md).
- `SimpleZoom.glsl`: the `zoomin` mode of [xfade](../ffmpeg/xfade/README.md).
- `Directional.glsl`, `DirectionalWipe.glsl`, `Fade.glsl`, `FadeColor.glsl`, `FadeGrayscale.glsl`, `CircleOpen.glsl`, `Pixelize.glsl`, `Wind.glsl`, `HorizontalOpen/Close.glsl`, `VerticalOpen/Close.glsl`: the slide, wipe, fade, fadeblack/fadewhite, fadegrays, circleopen, pixelize, wind, horzopen/horzclose and vertopen/vertclose modes of [xfade](../ffmpeg/xfade/README.md).
