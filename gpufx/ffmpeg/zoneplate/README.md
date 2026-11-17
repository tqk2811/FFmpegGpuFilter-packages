# Zone Plate

Zone plate test pattern, like FFmpeg's `zoneplate` source: rings, sweeps and moving patterns from a sine of a phase polynomial in x, y and time.

## Inputs

- `src`: Sets the size and is blended in by `opacity` (see Notes).

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `zoneplate.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `lut_precision` | int | `10` | 4 to 16 | Bits of the sine lookup table: 2^lut_precision entries per period (FFmpeg's precision; that name is reserved in WGSL) |
| `xo` | int | `0` |  | X-axis offset of the centre, in pixels |
| `yo` | int | `0` |  | Y-axis offset of the centre, in pixels |
| `to` | int | `0` |  | T-axis offset, in frames |
| `k0` | int | `0` |  | 0-order phase |
| `kx` | int | `0` |  | 1-order X-axis phase |
| `ky` | int | `0` |  | 1-order Y-axis phase |
| `kt` | int | `0` |  | 1-order T-axis phase |
| `kxt` | int | `0` |  | X-axis * T-axis product phase |
| `kyt` | int | `0` |  | Y-axis * T-axis product phase |
| `kxy` | int | `0` |  | X-axis * Y-axis product phase |
| `kx2` | int | `0` |  | 2-order X-axis phase |
| `ky2` | int | `0` |  | 2-order Y-axis phase |
| `kt2` | int | `0` |  | 2-order T-axis phase |
| `ku` | int | `0` |  | 0-order U-color phase |
| `kv` | int | `0` |  | 0-order V-color phase |
| `rate` | float | `25` | 1 to 1000 | Frame rate that turns the time into FFmpeg's frame number t (the source's rate option) |
| `opacity` | float | `1` | 0 to 1 | Blend over the input picture: 1 = only the generated picture, 0 = the input unchanged |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='zoneplate.zip=kx2=64&ky2=64&kt2=1',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='zoneplate.zip=kx2=64&ky2=64&kt2=1',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'zoneplate.zip=kx2=64&ky2=64&kt2=1' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `zoneplate` source (`vsrc_testsrc.c`). Each pixel's phase is `k0 + kx x + ky y + kt t + kxt x t + kyt y t + kxy x y + kx2 x^2 + ky2 y^2 + kt2 t^2`, with FFmpeg's scaling of the product terms and its 32-bit integer arithmetic (wrapping on overflow), so the pattern is the same pixel for pixel; Y is the sine table at the phase, U and V the table at the phase plus `ku` and `kv`. `t` is FFmpeg's frame number, the time times `rate`, plus `to`.

The effect has no source of its own: gpufx effects always have an input, so `src` only sets the size (and is blended in by `opacity`). Use any video of the wanted size, for example `-f lavfi -i color=black:s=1280x720:r=25`.

Checked against FFmpeg's `zoneplate` converted to RGBA, at several frames and settings (`kx2=64:ky2=64`; all terms with `ku`, `kv`; `precision=8` with offsets): at most 3 8-bit levels apart (mean under 0.03), from the Y'CbCr to RGB conversion.

Differences from FFmpeg:

- FFmpeg writes full-range Y'CbCr planes; here the same values are decoded to RGB with full-range BT.601, as FFmpeg's own conversion to RGB does.
- FFmpeg's `precision` is `lut_precision` here (`precision` is a reserved word in WGSL).
- The size, rate and duration options of the source are not ported: the size is the input's and the time is the stream's.
