# hqx

Magnifies pixel art 2, 3 or 4 times with hqx (hq2x, hq3x, hq4x), like FFmpeg's `hqx`.

## Inputs

- `src`: Picture to magnify.

Any size whose magnified size fits the GPU; any pixel format that gpufx converts on the GPU.

## Output

`n` times the size of the input. Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `hqx.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `n` | int | `3` | 2 to 4 | Scale factor; sets the output size, so it must not change while the stream runs |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='hqx.zip=n=4',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='hqx.zip=n=4',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'hqx.zip=n=4' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `hqx` (`vf_hqx.c`). The eight neighbours that differ from the centre pixel in FFmpeg's integer YUV (thresholds 48, 7, 6) form a pattern, and FFmpeg's rules turn the pattern into each sub-pixel of the `n` x `n` block, as a copy of the centre or a blend with up to two neighbours. Pixels are handled as FFmpeg's RGB32 words and the blends use its bit masks, so they round the same way; alpha is blended like the colors, as in FFmpeg. The edge pixels repeat past the picture. The output size comes from `n`, which therefore must not change while the stream runs.

Checked against FFmpeg's `hqx` with `n=2`, `3` and `4` on a posterized pixel-art picture and on a photo: identical.
