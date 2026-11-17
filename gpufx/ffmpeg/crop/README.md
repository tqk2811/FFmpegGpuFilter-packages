# Crop

Cuts a rectangle out of the picture, like FFmpeg's `crop` filter. The output has the size of the rectangle.

## Inputs

- `src`

Any size; any pixel format that gpufx converts on the GPU.

## Output

`w` x `h` (0 is the input's side), no larger than the input. The size is computed once, when the filter is configured: `w` and `h` must not change while the stream runs, but `x` and `y` may (a moving crop). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `crop.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `w` | int | `0` | 0 to 16384 | Width of the rectangle in pixels; 0 = the input's width (`out_w`) |
| `h` | int | `0` | 0 to 16384 | Height of the rectangle in pixels; 0 = the input's height (`out_h`) |
| `x` | int | `-1` | -1 to 16384 | Left edge of the rectangle; -1 = centred |
| `y` | int | `-1` | -1 to 16384 | Top edge of the rectangle; -1 = centred |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='crop.zip=w=1280&h=720&x=-1&y=-1',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='crop.zip=w=1280&h=720&x=-1&y=-1',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'crop.zip=w=1280&h=720&x=-1&y=-1' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `crop` (`vf_crop.c`). One pass of `textureLoad`. `-1` for `x` or `y` centres the rectangle like FFmpeg's default `(in_w-out_w)/2`, rounded half to even as FFmpeg does; a rectangle reaching past the picture is moved back inside, as FFmpeg clips `x` and `y`.

Checked against FFmpeg's `crop` with given and centred positions, odd sizes and a position past the edge: identical.

Differences from FFmpeg:

- `w`, `h`, `x` and `y` are numbers (or the FFmpeg expressions of the option, evaluated at `t=0` for `w` and `h`), not `vf_crop`'s own expressions in `in_w`, `out_w`, `x`, `y`; write `-1` for a centred rectangle.
- `keep_aspect` and `exact` are not ported: the picture is RGBA on the GPU, so no rounding to the chroma subsampling is needed.
