# nanotrack-v2

NanoTrack V2, a light Siamese single object tracker, as a gpufx-nn tracker package (`tracker.json`, kind
`siamese`) for object tracking in the gpufx editor (`gpufx_ai_tracking`, `NanoTrack` of gpufx-core).

## Source

The models are `nanotrack_backbone_sim.onnx` and `nanotrack_head_sim.onnx` of NanoTrackV2 in
[SiamTrackers](https://github.com/HonglinChu/SiamTrackers/tree/master/NanoTrack) by Honglin Chu (the same files
OpenCV's `TrackerNano` loads), pinned at commit `8fe6791f`. Each was converted to ncnn by pnnx with f32 weights
and to gpufx-nn by `gpufx-nnconv`: the head's pixelwise correlation (a `MatMul` of the flattened template and
search features) becomes the `correlation` op. `scripts/convert-tracking-models.py` of the gpufx repository does
all of it; `source.json` pins every file by sha256.

## Use

- `backbone/`: a crop of the frame, 3 x S x S, BGR values in [0, 255], to features 48 x 8 x 8 for the
  127 pixel template and 48 x 16 x 16 for the 255 pixel search region.
- `head/`: inputs `in0` (template features) and `in1` (search features); outputs `out0`, 2 x 16 x 16 class
  scores (softmax over the two channels, channel 1 is the object), and `out1`, 4 x 16 x 16 distances from each
  cell to the box sides (left, top, right, bottom, in search pixels).
- `tracker.json`: crop sizes, stride, and the window, size penalty and size rate of the box decoding (SiamBAN).

## License

See the `LICENSE` file inside the package zip (put there with the models by the conversion script, not kept in
this folder; Apache License 2.0, the license of NanoTrack in the SiamTrackers
repository, which covers its code and its pre-trained models). Read it before redistributing the package.
