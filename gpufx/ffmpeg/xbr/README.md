# xBR

Magnifies pixel art 2, 3 or 4 times with xBR, like FFmpeg's `xbr`.

## Inputs

- `src`: Picture to magnify.

Any size whose magnified size fits the GPU; any pixel format that gpufx converts on the GPU.

## Output

`n` times the size of the input. Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `xbr.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `n` | int | `3` | 2 to 4 | Scale factor; sets the output size, so it must not change while the stream runs |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='xbr.zip=n=4',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='xbr.zip=n=4',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'xbr.zip=n=4' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `xbr` (`vf_xbr.c`). Each input pixel becomes an `n` x `n` block, starting as a copy of the pixel; at each of its four corners the 21-pixel neighbourhood decides whether an edge crosses it, and the block's sub-pixels there are blended towards the neighbour along the edge. Colors are compared through FFmpeg's integer YUV, pixels are handled as FFmpeg's RGB32 words and the blends use its bit masks, so they round the same way. Each thread works out the whole block of its source pixel and keeps its own sub-pixel. The edge pixels repeat past the picture. The output size comes from `n`, which therefore must not change while the stream runs.

Checked against FFmpeg's `xbr` with `n=2`, `3` and `4` on a posterized pixel-art picture and on a photo: identical in R, G, B.

Differences from FFmpeg:

- FFmpeg's blends clear the alpha byte of the blended sub-pixels; here every sub-pixel keeps the alpha of its source pixel.
