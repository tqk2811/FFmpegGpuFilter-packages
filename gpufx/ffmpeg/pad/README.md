# Pad

Places the picture on a larger canvas of one colour, like FFmpeg's `pad` filter. The output has the size of the canvas.

## Inputs

- `src`

Any size; any pixel format that gpufx converts on the GPU.

## Output

`w` x `h` (0 is the input's side), no smaller than the input. The size is computed once, when the filter is configured: `w` and `h` must not change while the stream runs, but `x`, `y` and `color` may. Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `pad.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `w` | int | `0` | 0 to 16384 | Width of the canvas in pixels; 0 = the input's width |
| `h` | int | `0` | 0 to 16384 | Height of the canvas in pixels; 0 = the input's height |
| `x` | int | `0` | -1 to 16384 | Left edge of the picture on the canvas; -1 = centred |
| `y` | int | `0` | -1 to 16384 | Top edge of the picture on the canvas; -1 = centred |
| `color` | color | `#000000` |  | Colour of the canvas (with alpha) |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='pad.zip=w=1920&h=1080&x=-1&y=-1',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='pad.zip=w=1920&h=1080&x=-1&y=-1',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'pad.zip=w=1920&h=1080&x=-1&y=-1' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `pad` (`vf_pad.c`). One pass: pixels inside the picture are copied with `textureLoad`, the others get `color`. `-1` for `x` or `y` centres the picture like FFmpeg's negative values (`(out_w-in_w)/2`, rounded down); a position that would push the picture past the canvas is moved back inside.

Checked against FFmpeg's `pad` with given and centred positions, odd sizes and a colour: identical.

Differences from FFmpeg:

- `w`, `h`, `x` and `y` are numbers (or the FFmpeg expressions of the option, evaluated at `t=0` for `w` and `h`), not `vf_pad`'s own expressions in `in_w`, `in_h`, `a`; FFmpeg refuses a picture that does not fit where this port moves it.
- `aspect` and `eval` are not ported; `color` is written `#rrggbb` or `#rrggbbaa`, not FFmpeg colour names.
