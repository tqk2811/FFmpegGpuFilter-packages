# gl-transitions

GPU ports of transitions from [gl-transitions](https://github.com/gl-transitions/gl-transitions). Each package is a `progress` (0 to 1) driven transition between two clips of the same size. The GLSL of each original is rewritten in WGSL, keeping its coordinates (y up) and its look; at `progress` 0 and 1 the packages show the exact clips. Parameters that are points (`center`) are given y down, as in the other gpufx packages.

Licenses: every original here is MIT except `InvertedPageCurl.glsl` (BSD 3-Clause, Hewlett-Packard) and `StereoViewer.glsl` (BSD 2-Clause, Ted Schundler). The texts and the author of each file are in [LICENSE](LICENSE).

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
| [color-wrap](color-wrap/README.md) | [ColorWrap.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ColorWrap.glsl) | Yoni Maltsman | MIT |
| [hsv-fade](hsv-fade/README.md) | [HsvFade.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HsvFade.glsl) | nwoeanhinnogaehr | MIT |
| [overexposure](overexposure/README.md) | [Overexposure.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Overexposure.glsl) | Ben Zhang | MIT |
| [glitch-bands](glitch-bands/README.md) | [GlitchBands.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitchBands.glsl) | Yoni Maltsman | MIT |
| [diamond-wipe](diamond-wipe/README.md) | [DiamondWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DiamondWipe.glsl) | gre | MIT |
| [leaf-wipe](leaf-wipe/README.md) | [LeafWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LeafWipe.glsl) | @Flexi23 | MIT |
| [spiral-wipe](spiral-wipe/README.md) | [SpiralWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SpiralWipe.glsl) | gre | MIT |
| [star-wipe](star-wipe/README.md) | [StarWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StarWipe.glsl) | Ben Lucas | MIT |
| [keyhole-wipe](keyhole-wipe/README.md) | [KeyholeWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/KeyholeWipe.glsl) | gre | MIT |
| [static-wipe](static-wipe/README.md) | [StaticWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StaticWipe.glsl) | Ben Lucas | MIT |
| [luminance-melt](luminance-melt/README.md) | [LuminanceMelt.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LuminanceMelt.glsl) | 0gust1 | MIT |
| [fisheye](fisheye/README.md) | [Fisheye.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Fisheye.glsl) | gre | MIT |
| [zoom-in-out](zoom-in-out/README.md) | [ZoomInOut.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ZoomInOut.glsl) | OllyOllyOlly | MIT |
| [tunnel](tunnel/README.md) | [Tunnel.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Tunnel.glsl) | gre | MIT |
| [revolve](revolve/README.md) | [Revolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Revolve.glsl) | bread | MIT |
| [whip-pan](whip-pan/README.md) | [WhipPan.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WhipPan.glsl) | gre | MIT |
| [rotate-scale-vanish](rotate-scale-vanish/README.md) | [RotateScaleVanish.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RotateScaleVanish.glsl) | Mark Craig | MIT |
| [tv-turn-off](tv-turn-off/README.md) | [TvTurnOff.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TvTurnOff.glsl) | gre | MIT |
| [tv-roll](tv-roll/README.md) | [TvRoll.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TvRoll.glsl) | gre | MIT |
| [eye-blink](eye-blink/README.md) | [EyeBlink.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/EyeBlink.glsl) | gre | MIT |
| [simple-flip](simple-flip/README.md) | [SimpleFlip.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SimpleFlip.glsl) | nwoeanhinnogaehr | MIT |
| [fold](fold/README.md) | [Fold.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Fold.glsl) | nwoeanhinnogaehr | MIT |
| [accordion](accordion/README.md) | [Accordion.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Accordion.glsl) | gre | MIT |
| [book-flip](book-flip/README.md) | [BookFlip.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BookFlip.glsl) | hong | MIT |
| [card-swipe](card-swipe/README.md) | [CardSwipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CardSwipe.glsl) | gre | MIT |
| [curtains](curtains/README.md) | [Curtains.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Curtains.glsl) | gre | MIT |
| [inside-cube](inside-cube/README.md) | [InsideCube.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/InsideCube.glsl) | gre | MIT |
| [prisms](prisms/README.md) | [Prisms.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Prisms.glsl) | gre | MIT |
| [sphere](sphere/README.md) | [Sphere.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Sphere.glsl) | gre | MIT |
| [grid-flip](grid-flip/README.md) | [GridFlip.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GridFlip.glsl) | TimDonselaar | MIT |
| [vortex](vortex/README.md) | [Vortex.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Vortex.glsl) | gre | MIT |
| [shockwave](shockwave/README.md) | [Shockwave.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Shockwave.glsl) | Gilad Levi | MIT |
| [shatter](shatter/README.md) | [Shatter.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Shatter.glsl) | lbl | MIT |
| [tile-blast](tile-blast/README.md) | [TileBlast.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TileBlast.glsl) | gre | MIT |
| [puzzle](puzzle/README.md) | [Puzzle.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Puzzle.glsl) | gre | MIT |
| [paper-fold](paper-fold/README.md) | [PaperFold.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PaperFold.glsl) | gre | MIT |
| [unbox](unbox/README.md) | [Unbox.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Unbox.glsl) | gre | MIT |
| [whittle](whittle/README.md) | [Whittle.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Whittle.glsl) | gre | MIT |
| [shred](shred/README.md) | [Shred.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Shred.glsl) | gre | MIT |
| [fall-over](fall-over/README.md) | [FallOver.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FallOver.glsl) | gre | MIT |
| [ribbon-twist](ribbon-twist/README.md) | [RibbonTwist.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RibbonTwist.glsl) | gre | MIT |
| [camera-shake](camera-shake/README.md) | [CameraShake.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CameraShake.glsl) | gre | MIT |
| [warp-speed](warp-speed/README.md) | [WarpSpeed.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WarpSpeed.glsl) | gre | MIT |
| [tangent-motion-blur](tangent-motion-blur/README.md) | [TangentMotionBlur.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TangentMotionBlur.glsl) | chenkai | MIT |
| [whip-spin](whip-spin/README.md) | [WhipSpin.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WhipSpin.glsl) | gre | MIT |
| [gravity-lens](gravity-lens/README.md) | [GravityLens.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GravityLens.glsl) | gre | MIT |
| [bottleneck](bottleneck/README.md) | [Bottleneck.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Bottleneck.glsl) | gre | MIT |
| [power-kaleido](power-kaleido/README.md) | [PowerKaleido.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PowerKaleido.glsl) | Boundless | MIT |
| [lissajous-tiles](lissajous-tiles/README.md) | [LissajousTiles.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LissajousTiles.glsl) | Boundless | MIT |
| [comb](comb/README.md) | [Comb.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Comb.glsl) | gre | MIT |
| [tv-lost-signal](tv-lost-signal/README.md) | [TvLostSignal.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TvLostSignal.glsl) | mernking | MIT |
| [plus-wipe](plus-wipe/README.md) | [PlusWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PlusWipe.glsl) | gre | MIT |
| [xor-wipe](xor-wipe/README.md) | [XorWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/XorWipe.glsl) | gre | MIT |
| [circle-burst](circle-burst/README.md) | [CircleBurst.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CircleBurst.glsl) | gre | MIT |
| [dither-dissolve](dither-dissolve/README.md) | [DitherDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DitherDissolve.glsl) | gre | MIT |
| [film-dissolve](film-dissolve/README.md) | [FilmDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FilmDissolve.glsl) | gre | MIT |
| [plasma-dissolve](plasma-dissolve/README.md) | [PlasmaDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PlasmaDissolve.glsl) | gre | MIT |
| [honeycomb](honeycomb/README.md) | [Honeycomb.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Honeycomb.glsl) | gre | MIT |
| [defocus-blur](defocus-blur/README.md) | [DefocusBlur.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DefocusBlur.glsl) | Sergey Kosarevsky | MIT |
| [halftone](halftone/README.md) | [Halftone.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Halftone.glsl) | gre | MIT |
| [photo-develop](photo-develop/README.md) | [PhotoDevelop.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PhotoDevelop.glsl) | gre | MIT |
| [chessboard](chessboard/README.md) | [Chessboard.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Chessboard.glsl) | lql | MIT |
| [wedge-wipe](wedge-wipe/README.md) | [WedgeWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WedgeWipe.glsl) | gre | MIT |
| [snake-block-wipe](snake-block-wipe/README.md) | [SnakeBlockWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SnakeBlockWipe.glsl) | gre | MIT |
| [aperture-wipe](aperture-wipe/README.md) | [ApertureWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ApertureWipe.glsl) | gre | MIT |
| [curved-wipe](curved-wipe/README.md) | [CurvedWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CurvedWipe.glsl) | gre | MIT |
| [shutter-wipe](shutter-wipe/README.md) | [ShutterWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ShutterWipe.glsl) | gre | MIT |
| [iris-fold](iris-fold/README.md) | [IrisFold.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/IrisFold.glsl) | gre | MIT |
| [moire-wipe](moire-wipe/README.md) | [MoireWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/MoireWipe.glsl) | gre | MIT |
| [tiles-wave](tiles-wave/README.md) | [TilesWave.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TilesWave.glsl) | numb3r23 | MIT |
| [glow-dissolve](glow-dissolve/README.md) | [GlowDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlowDissolve.glsl) | hjm1fb | MIT |
| [edge-glow](edge-glow/README.md) | [EdgeGlow.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/EdgeGlow.glsl) | Woohyun Kim | MIT |
| [spotlight-wipe](spotlight-wipe/README.md) | [SpotlightWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SpotlightWipe.glsl) | gre | MIT |
| [curtain-rise](curtain-rise/README.md) | [CurtainRise.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CurtainRise.glsl) | gre | MIT |
| [projector-throw](projector-throw/README.md) | [ProjectorThrow.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ProjectorThrow.glsl) | gre | MIT |
| [reeded-glass](reeded-glass/README.md) | [ReededGlass.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ReededGlass.glsl) | gre | MIT |
| [pixel-stretch](pixel-stretch/README.md) | [PixelStretch.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PixelStretch.glsl) | gre | MIT |
| [funnel](funnel/README.md) | [Funnel.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Funnel.glsl) | gre | MIT |
| [nightfall](nightfall/README.md) | [Nightfall.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Nightfall.glsl) | gre | MIT |
| [band-wipe](band-wipe/README.md) | [BandWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BandWipe.glsl) | gre | MIT |
| [sawtooth-wipe](sawtooth-wipe/README.md) | [SawtoothWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SawtoothWipe.glsl) | gre | MIT |
| [lens-wipe](lens-wipe/README.md) | [LensWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LensWipe.glsl) | gre | MIT |
| [ink-bleed](ink-bleed/README.md) | [InkBleed.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/InkBleed.glsl) | gre | MIT |
| [bloom-dissolve](bloom-dissolve/README.md) | [BloomDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BloomDissolve.glsl) | gre | MIT |
| [gooey-wipe](gooey-wipe/README.md) | [GooeyWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GooeyWipe.glsl) | gre | MIT |
| [equalizer-wipe](equalizer-wipe/README.md) | [EqualizerWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/EqualizerWipe.glsl) | gre | MIT |
| [hologram](hologram/README.md) | [Hologram.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Hologram.glsl) | gre | MIT |
| [snapshot](snapshot/README.md) | [Snapshot.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Snapshot.glsl) | gre | MIT |
| [split-flap](split-flap/README.md) | [SplitFlap.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SplitFlap.glsl) | gre | MIT |
| [vaporize](vaporize/README.md) | [Vaporize.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Vaporize.glsl) | gre | MIT |
| [flame-wipe](flame-wipe/README.md) | [FlameWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FlameWipe.glsl) | gre | MIT |
| [arrow-wipe](arrow-wipe/README.md) | [ArrowWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ArrowWipe.glsl) | gre | MIT |
| [rings-wipe](rings-wipe/README.md) | [RingsWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RingsWipe.glsl) | gre | MIT |
| [truchet-wipe](truchet-wipe/README.md) | [TruchetWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TruchetWipe.glsl) | gre | MIT |
| [waterfall-wipe](waterfall-wipe/README.md) | [WaterfallWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WaterfallWipe.glsl) | gre | MIT |
| [frost-wipe](frost-wipe/README.md) | [FrostWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FrostWipe.glsl) | gre | MIT |
| [splatter-wipe](splatter-wipe/README.md) | [SplatterWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SplatterWipe.glsl) | gre | MIT |
| [code-rain](code-rain/README.md) | [CodeRain.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CodeRain.glsl) | gre | MIT |
| [led-wall](led-wall/README.md) | [LedWall.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LedWall.glsl) | gre | MIT |
| [card-deal](card-deal/README.md) | [CardDeal.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CardDeal.glsl) | gre | MIT |
| [light-wipe](light-wipe/README.md) | [LightWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LightWipe.glsl) | gre | MIT |
| [heat-haze](heat-haze/README.md) | [HeatHaze.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HeatHaze.glsl) | gre | MIT |
| [tile-shuffle](tile-shuffle/README.md) | [TileShuffle.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TileShuffle.glsl) | gre | MIT |
| [slot-reels](slot-reels/README.md) | [SlotReels.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SlotReels.glsl) | gre | MIT |
| [ascii](ascii/README.md) | [Ascii.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Ascii.glsl) | gre | MIT |
| [vhs-tracking](vhs-tracking/README.md) | [VhsTracking.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/VhsTracking.glsl) | gre | MIT |
| [brush-wipe](brush-wipe/README.md) | [BrushWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BrushWipe.glsl) | gre | MIT |
| [domino-fall](domino-fall/README.md) | [DominoFall.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DominoFall.glsl) | gre | MIT |
| [tumble](tumble/README.md) | [Tumble.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Tumble.glsl) | gre | MIT |
| [lens-flare](lens-flare/README.md) | [LensFlare.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LensFlare.glsl) | gre | MIT |
| [bokeh-dissolve](bokeh-dissolve/README.md) | [BokehDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BokehDissolve.glsl) | gre | MIT |
| [light-rays](light-rays/README.md) | [LightRays.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LightRays.glsl) | gre | MIT |
| [soap-drop](soap-drop/README.md) | [SoapDrop.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SoapDrop.glsl) | gre | MIT |
| [speed-lines](speed-lines/README.md) | [SpeedLines.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SpeedLines.glsl) | gre | MIT |
| [film-strip](film-strip/README.md) | [FilmStrip.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FilmStrip.glsl) | gre | MIT |
| [cylinder-roll](cylinder-roll/README.md) | [CylinderRoll.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CylinderRoll.glsl) | gre | MIT |
| [dam-break](dam-break/README.md) | [DamBreak.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DamBreak.glsl) | gre | MIT |
| [cymatics](cymatics/README.md) | [Cymatics.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Cymatics.glsl) | gre | MIT |
| [glitter-dissolve](glitter-dissolve/README.md) | [GlitterDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitterDissolve.glsl) | gre | MIT |
| [paper-tear](paper-tear/README.md) | [PaperTear.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PaperTear.glsl) | gre | MIT |
| [marbling-dissolve](marbling-dissolve/README.md) | [MarblingDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/MarblingDissolve.glsl) | gre | MIT |
| [disintegrate](disintegrate/README.md) | [Disintegrate.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Disintegrate.glsl) | gre | MIT |
| [honey-drip](honey-drip/README.md) | [HoneyDrip.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HoneyDrip.glsl) | gre | MIT |
| [stop-motion](stop-motion/README.md) | [StopMotion.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StopMotion.glsl) | gre | MIT |
| [liquid-fill](liquid-fill/README.md) | [LiquidFill.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LiquidFill.glsl) | gre | MIT |
| [refraction](refraction/README.md) | [Refraction.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Refraction.glsl) | gre | MIT |
| [subdivide](subdivide/README.md) | [Subdivide.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Subdivide.glsl) | gre | MIT |
| [quadtree-blocks](quadtree-blocks/README.md) | [QuadtreeBlocks.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/QuadtreeBlocks.glsl) | gre | MIT |
| [bead-up](bead-up/README.md) | [BeadUp.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BeadUp.glsl) | gre | MIT |
| [billow-wipe](billow-wipe/README.md) | [BillowWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BillowWipe.glsl) | gre | MIT |
| [ring-spin](ring-spin/README.md) | [RingSpin.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RingSpin.glsl) | gre | MIT |
| [pinch-lift](pinch-lift/README.md) | [PinchLift.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PinchLift.glsl) | gre | MIT |
| [knead](knead/README.md) | [Knead.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Knead.glsl) | gre | MIT |
| [gallery](gallery/README.md) | [Gallery.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Gallery.glsl) | gre | MIT |
| [swim](swim/README.md) | [Swim.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Swim.glsl) | gre | MIT |
| [shore-wash](shore-wash/README.md) | [ShoreWash.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ShoreWash.glsl) | gre | MIT |
| [crumple](crumple/README.md) | [Crumple.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Crumple.glsl) | gre | MIT |
| [drape](drape/README.md) | [Drape.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Drape.glsl) | gre | MIT |
| [paint-dissolve](paint-dissolve/README.md) | [PaintDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PaintDissolve.glsl) | gre | MIT |
| [watercolor-dissolve](watercolor-dissolve/README.md) | [WatercolorDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WatercolorDissolve.glsl) | gre | MIT |
| [puzzle-cube](puzzle-cube/README.md) | [PuzzleCube.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PuzzleCube.glsl) | gre | MIT |
| [clothesline](clothesline/README.md) | [Clothesline.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Clothesline.glsl) | gre | MIT |
| [poster-paste](poster-paste/README.md) | [PosterPaste.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PosterPaste.glsl) | gre | MIT |
| [geometric-collage](geometric-collage/README.md) | [GeometricCollage.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GeometricCollage.glsl) | gre | MIT |
| [film-leader](film-leader/README.md) | [FilmLeader.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FilmLeader.glsl) | gre | MIT |
| [lightning-flash](lightning-flash/README.md) | [LightningFlash.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LightningFlash.glsl) | gre | MIT |
| [glitch-flicker](glitch-flicker/README.md) | [GlitchFlicker.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitchFlicker.glsl) | bread | MIT |
| [strip-datamosh-glitch](strip-datamosh-glitch/README.md) | [StripDatamoshGlitch.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StripDatamoshGlitch.glsl) | bread | MIT |
| [smoke-dissolve](smoke-dissolve/README.md) | [SmokeDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SmokeDissolve.glsl) | gre | MIT |
| [diffuse-dissolve](diffuse-dissolve/README.md) | [DiffuseDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DiffuseDissolve.glsl) | gre | MIT |
| [color-panel-wipe](color-panel-wipe/README.md) | [ColorPanelWipe.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ColorPanelWipe.glsl) | gre | MIT |
| [disc-cascade](disc-cascade/README.md) | [DiscCascade.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DiscCascade.glsl) | gre | MIT |
| [corner-pin](corner-pin/README.md) | [CornerPin.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CornerPin.glsl) | gre | MIT |
| [cleave](cleave/README.md) | [Cleave.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Cleave.glsl) | gre | MIT |
| [coin-settle](coin-settle/README.md) | [CoinSettle.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CoinSettle.glsl) | gre | MIT |
| [deinterleave](deinterleave/README.md) | [Deinterleave.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Deinterleave.glsl) | gre | MIT |
| [block-cover](block-cover/README.md) | [BlockCover.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BlockCover.glsl) | gre | MIT |
| [cell-dissolve](cell-dissolve/README.md) | [CellDissolve.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CellDissolve.glsl) | gre | MIT |
| [stereo-viewer](stereo-viewer/README.md) | [StereoViewer.glsl](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StereoViewer.glsl) | Ted Schundler | BSD 2-Clause |

Not ported because an existing package already does the same:

- `RadialWipe.glsl` (Radial): the `radial` mode of [xfade](../ffmpeg/xfade/README.md) and [clock-wipe](../tqk2811/TqkLibrary.FFmpegTransition/clock-wipe/README.md).
- `WindowSlices.glsl` (windowslice): the `hlslice` mode of [xfade](../ffmpeg/xfade/README.md).
- `SimpleZoom.glsl`: the `zoomin` mode of [xfade](../ffmpeg/xfade/README.md).
- `Directional.glsl`, `DirectionalWipe.glsl`, `Fade.glsl`, `FadeColor.glsl`, `FadeGrayscale.glsl`, `CircleOpen.glsl`, `Pixelize.glsl`, `Wind.glsl`, `HorizontalOpen/Close.glsl`, `VerticalOpen/Close.glsl`: the slide, wipe, fade, fadeblack/fadewhite, fadegrays, circleopen, pixelize, wind, horzopen/horzclose and vertopen/vertclose modes of [xfade](../ffmpeg/xfade/README.md).
