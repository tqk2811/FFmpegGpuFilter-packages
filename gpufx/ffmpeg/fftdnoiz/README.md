# FFT Denoiser

FFT block denoiser on a single frame, like FFmpeg's `fftdnoiz` without its temporal part.

## Inputs

- `src`: Picture to denoise.

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `fftdnoiz.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `sigma` | float | `1.0` | 0.0 to 100.0 | Denoising strength |
| `amount` | float | `1.0` | 0.01 to 1.0 | Amount of denoising: the weakest frequencies keep 1 - amount of their size |
| `block` | int | `32` | 8 to 64 | Block size in pixels |
| `overlap` | float | `0.5` | 0.2 to 0.8 | Overlap of the blocks, as a fraction of the block size |
| `method` | enum | `wiener` | `wiener`, `hard` | Scaling of each frequency: Wiener filter from its power, or hard threshold |
| `planes` | int | `7` | 0 to 15 | Channels to filter, FFmpeg's bits on gbrp: 1 green, 2 blue, 4 red |
| `window` | enum | `hanning` | `rect`, `bartlett`, `hann`, `hanning`, `hamming`, `blackman`, `welch`, `flattop`, `bharris`, `bnuttall`, `bhann`, `sine`, `nuttall`, `lanczos`, `gauss`, `tukey`, `cauchy`, `parzen`, `poisson`, `bohman`, `kaiser` | Window function of the blocks |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='fftdnoiz.zip=sigma=5&block=32&overlap=0.5',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='fftdnoiz.zip=sigma=5&block=32&overlap=0.5',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'fftdnoiz.zip=sigma=5&block=32&overlap=0.5' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `fftdnoiz` (`vf_fftdnoiz.c`) with `prev=0:next=0`, on each R, G, B channel as FFmpeg does on `gbrp`. The picture is cut in `block` x `block` blocks that step by `size = block - round(block * overlap)` pixels. Each block is multiplied by the window, turned into its 2-D spectrum, and every frequency of power `p` is scaled by `max(1 - amount, (p - s) / p)` (`wiener`) or by `1 - amount` when `p < s` (`hard`), `s` being `sigma / block^2`; the inverse transform, divided by the window, gives the middle `size` x `size` pixels of the block, so each pixel comes from exactly one block. FFmpeg's edge handling is kept: rows and columns past the picture repeat the last ones, rows above the picture are mirrored, and the columns left of a block are mirrored around its first column (FFmpeg takes the absolute value of the offset inside the row). A zero window weight gives 0, as FFmpeg's `lrintf` does. Alpha is passed through.

One pass per channel and a pass that merges them. A workgroup takes a block at a time and keeps half of its conjugate-symmetric spectrum (`block^2` floats) in workgroup memory; the transforms are plain DFTs spread over the 64 threads. About 78 ms for a 1920x1080 frame with the defaults on a laptop RTX 4060 (40 ms with `block=16`, 150 ms with `block=64`, 320 ms with `overlap=0.8`).

Checked against FFmpeg's `format=gbrp,loop=1:1,fftdnoiz` on a noisy test picture (643x361 and 1920x1080; defaults; `sigma=10:block=24:overlap=0.3:method=hard:amount=0.8:window=blackman`; `sigma=6:block=64:overlap=0.8:planes=5:window=kaiser`; odd blocks 17 and 63; `block=8:overlap=0.8`; every window): identical except a few pixels 1 level apart. The `loop` makes FFmpeg work on a copy: on a writable frame it filters in place, so a block reads the already denoised rows of the block above, and its result depends on the number of threads (up to 6 levels apart between 1 and 8 threads); this package does not reproduce that.

Differences from FFmpeg:

- `prev` and `next` (temporal denoising with the neighbouring frames) are not ported: effects keep no frames.
- `block` stops at 64 (FFmpeg allows 256): half the spectrum of a 64 x 64 block fills the 16 KiB of workgroup memory WebGPU guarantees. Larger blocks would need more workgroup memory or float intermediate textures of a size other than the frame.
- The `dolph` window is not ported; `hann` is `hanning`.
- `planes` uses FFmpeg's bits for `gbrp` (1 green, 2 blue, 4 red); bit 8 (alpha) does nothing. YUV video is filtered in RGB, not per Y, U, V plane.
- Values are handled as 8-bit codes, also for video with more bits.
