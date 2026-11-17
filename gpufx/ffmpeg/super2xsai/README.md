# Super 2xSaI

Magnifies pixel art 2 times with Super 2xSaI, like FFmpeg's `super2xsai`.

## Inputs

- `src`: Picture to magnify.

Any size whose doubled size fits the GPU; any pixel format that gpufx converts on the GPU.

## Output

Twice the size of the input. Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

None.

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='super2xsai.zip',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='super2xsai.zip',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'super2xsai.zip' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `super2xsai` (`vf_super2xsai.c`), as FFmpeg runs it on RGBA. Each input pixel becomes 2 x 2 pixels chosen or blended from its 4 x 4 neighbourhood. Pixels are compared as whole RGBA 8-bit values, alpha included, and the blends use FFmpeg's per-byte bit masks, so they round the same way. The edge pixels repeat past the picture.

Checked against FFmpeg's `super2xsai` on a posterized pixel-art picture and on a photo: identical.
