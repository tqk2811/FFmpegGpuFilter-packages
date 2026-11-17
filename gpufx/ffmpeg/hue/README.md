# Hue

Rotates the hue, scales the saturation and shifts the brightness the way FFmpeg's `hue` filter does.

## Inputs

- `src`

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `hue.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `h` | float | `0` | -3600 to 3600 | Hue angle in degrees |
| `s` | float | `1` | -10 to 10 | Saturation (0 = gray, negative also inverts the hue) |
| `b` | float | `0` | -10 to 10 | Brightness: each unit adds 25.6 luma levels |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='hue.zip=h=90&s=1.2',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='hue.zip=h=90&s=1.2',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'hue.zip=h=90&s=1.2' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `hue` (`vf_hue.c`). One pass on BT.709 limited-range Y'CbCr: the chroma vector (Cb, Cr) is rotated by `h` and multiplied by `s` (`Cb' = s * (cos h * Cb - sin h * Cr)`, `Cr' = s * (sin h * Cb + cos h * Cr)`), clipped to the 8-bit range as FFmpeg does, and the luma gets `b * 25.6` levels. Alpha is passed through. The hue package is not the same as `huesaturation` (which picks colour ranges) or the `hue` of `color-adjust` (a rotation around the RGB gray axis).

Checked against FFmpeg's `hue` run on BT.709 limited-range `yuv444p`: at most 3 8-bit levels apart.

Differences from FFmpeg:

- FFmpeg works on the planes of the stream as they are; gpufx hands the shader RGB, so the port always uses BT.709 limited range.
- `H` (the angle in radians) is not ported: use `h` in degrees. `h`, `s` and `b` are plain values or the usual FFmpeg expressions of the option, not `vf_hue`'s own expressions.
