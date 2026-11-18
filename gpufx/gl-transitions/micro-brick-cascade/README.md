# Micro Brick Cascade

The first clip fractures into a dense wall of tiny square tiles; a diagonal cascade releases the tiles in staggered waves, so they fall and drift aside while the second clip is revealed beneath. Drive `progress` from 0 to 1.

Port of [`MicroBrickCascade.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/MicroBrickCascade.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by Gilad Levi, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `micro-brick-cascade.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `tile_size` | float | `0.018` | 0.008 to 0.06 | Size of each square tile, relative to the frame height |
| `fall` | float | `1.1` | 0 to 2 | Downward falling strength of released tiles |
| `drift` | float | `0.35` | 0 to 1.5 | Sideways drift while the tiles fall |
| `diagonal` | float | `0.82` | 0 to 1 | How diagonal the release wave is |
| `stagger` | float | `0.45` | 0 to 1 | Random stagger between neighboring tiles |
| `softness` | float | `0.22` | 0 to 1 | Softness of the tiles' disappearance |
| `glow` | float | `0.45` | 0 to 1 | Brightness of the highlight on the edges of the moving tiles |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='micro-brick-cascade.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='micro-brick-cascade.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
