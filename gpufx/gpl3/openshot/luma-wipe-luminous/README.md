# Luma Wipe: Luminous (OpenShot)

A wipe that follows the brightness of one of 44 OpenShot grayscale luma images (glows, suns and stars): dark areas switch to the second clip first. Drive `progress` from 0 to 1.

**License: GPL-3.0-or-later** (see [LICENSE](LICENSE)). Unlike the MIT packages of this repository, this package holds images taken from OpenShot, so the whole package, its shader included, is distributed under the GNU GPL version 3 or later. Nothing in it is shared with other packages.

## Source

- Repository: [OpenShot/openshot-qt](https://github.com/OpenShot/openshot-qt), GPL-3.0-or-later, by OpenShot Studios, LLC and the OpenShot contributors
- Files: 44 of the 405 images of [`src/transitions/extra`](https://github.com/OpenShot/openshot-qt/tree/develop/src/transitions/extra), listed in [patterns.txt](patterns.txt)
- Commit: `4cdda487869bf9d2f6c01ece65602592f7aee130` (2026-11-16)

Changes made to the images: converted to 8-bit grayscale PNG and resized to 384x216 (the originals are 720x576 to 2688x1512, a mix of JPEG grayscale and RGB). [patterns.txt](patterns.txt) gives each pattern's number in this package, its name and its original file. The 405 images are split by name over ten packages so that each one loads only its own images; see the [OpenShot group](../README.md) for the others. The 7 SVG images of `src/transitions/common` (plain wipes, circle, fade) are not included: [xfade](../../../ffmpeg/xfade/README.md) has them.

The shader (`shaders/luma_wipe.wgsl`) is written for gpufx.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `luma-wipe-luminous.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `pattern` | enum | `luminous_boxes_1` | see [patterns.txt](patterns.txt) | Luma image (file name of the OpenShot original, lower case, other characters as `_`); its number in this package also works |
| `softness` | float | `0.1` | 0 to 1 | Width of the soft edge, in luma steps |
| `invert` | bool | `false` | - | Bright areas switch first |

The package loads its 44 images (about 3.6 M texels, some 14 MiB on the GPU) when it opens, whichever pattern is used.

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='luma-wipe-luminous.zip=pattern=luminous_frame_1&progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
