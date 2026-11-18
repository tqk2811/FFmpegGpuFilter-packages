# FFmpegGpuFilter packages

Effect packages and model descriptions for [FFmpegGpuFilter](https://github.com/tqk2811/FFmpegGpuFilter),
which mounts this repository as a git submodule at `packages/`.

| Folder | Contents |
|--------|----------|
| `gpufx/` | Effect packages (`manifest.json` + shaders), in group folders |
| `gpufx_ai_framerate/` | Model descriptions for `gpufx_ai_framerate` (RIFE) |
| `gpufx_ai_matting/` | Model descriptions for background removal, `gpufx_ai_matting` (MODNet, PP-HumanSeg) |
| `gpufx_ai_upscale/` | Model descriptions for `gpufx_ai_upscale` (Real-ESRGAN) |
| `gpufx_ai_tracking/` | Tracker and face detector descriptions for object tracking and the face censor, `gpufx_ai_tracking` (NanoTrack, YuNet) |

The model files themselves are not stored here: `scripts/fetch-models.sh` in FFmpegGpuFilter downloads and
converts them from the pinned URLs in each `source.json`; the matting models have no ncnn release, so
`scripts/convert-matting-models.py` builds them from their upstream files instead, and
`scripts/convert-tracking-models.py` the trackers from their ONNX files.

The tools and the format description live in FFmpegGpuFilter (`scripts/pack-packages.sh`,
[docs/EFFECT_FORMAT.md](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md)). The
READMEs here link to those docs with paths relative to the parent repository, so such links work from a
checkout of FFmpegGpuFilter and not on this repository's own pages.

## License

[MIT](LICENSE), except for the following, whose notices are next to the files:

| Part | License |
|------|---------|
| Leaf images of `gpufx/standalone/falling-maple` | Apache 2.0 (Noto Emoji, Google): `NOTICE.txt`, `LICENSE-Apache-2.0.txt` |
| Leaf images of `gpufx/standalone/falling-ginkgo` | CC BY 3.0 (game-icons.net, Delapouite): `NOTICE.txt` |
| Textures with a `textures/LICENSE.txt` | As stated in that file |
| Model files named by each `source.json` | The license of the model, fetched next to it as `LICENSE` |
