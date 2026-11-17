# EPX

Magnifies pixel art 2 or 3 times with EPX (Scale2x/Scale3x), like FFmpeg's `epx`.

## Inputs

- `src`: Picture to magnify.

Any size whose magnified size fits the GPU; any pixel format that gpufx converts on the GPU.

## Output

`n` times the size of the input. Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `epx.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `n` | int | `3` | 2 to 3 | Scale factor; sets the output size, so it must not change while the stream runs |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='epx.zip=n=2',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='epx.zip=n=2',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'epx.zip=n=2' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `epx` (`vf_epx.c`). Each input pixel becomes an `n` x `n` block; a sub-pixel takes the color of a neighbour when the neighbours around it match, which follows diagonal edges instead of making stairs. Pixels are compared as whole RGBA 8-bit values, alpha included, and the edge pixels repeat past the picture. The output size comes from `n`, which therefore must not change while the stream runs. Meant for pixel art and other flat-colored pictures: on photos almost no pixels match and the result is a nearest-neighbour enlargement.

Checked against FFmpeg's `epx` with `n=2` and `n=3` on a posterized pixel-art picture and on a photo: identical.
