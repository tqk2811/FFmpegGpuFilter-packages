# Gray World

Automatic white balance like FFmpeg's `grayworld`: it assumes the picture averages to gray and removes the mean color cast in a logarithmic LMS space.

## Inputs

- `src`: Picture to correct, taken as linear RGB (as FFmpeg does; sRGB video is used as it is).

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

None.

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='grayworld.zip',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='grayworld.zip',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'grayworld.zip' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `grayworld` (`vf_grayworld.c`). Each pixel goes from RGB to LMS, then to the log "lab" space of Reinhard's color transfer; the means of `a` and `b` over the whole frame are subtracted and the result goes back to RGB, clamped to 0..1. Alpha is passed through. The effect keeps no state between frames.

The frame means take three passes: the first sums `a` and `b` along each row (one thread per row and channel), the second adds the rows up in a single texel per channel, the last corrects the pixels. The sums travel between passes as the 32 bits of an `f32` spread over the four 8-bit channels of a texel, so they keep full precision in 8-bit textures. The picture must be at least 2 pixels wide.

Checked against FFmpeg's `grayworld` on the test picture: at most 1 8-bit level apart (mean 0.3).
