# pp-humanseg-v2-lite

PP-HumanSegV2-Lite (portrait) as a gpufx-nn package (`io.json` kind `matting`), for background removal with
`gpufx_ai_matting` / `FrameMatte` of the gpufx project. The fast one of the two matting packages: a 2-class
portrait segmentation at a fixed 256x144, its foreground probability used as alpha.

## Source

The weights are the `portrait_pp_humansegv2_lite_256x144_inference_model_with_softmax` inference model of
[PaddleSeg](https://github.com/PaddlePaddle/PaddleSeg) (`contrib/PP-HumanSeg`), as linked from its README,
exported to ONNX by paddle2onnx (the input fixed to 1x3x144x256), converted to ncnn by pnnx with f32 weights and
to gpufx-nn by `gpufx-nnconv`. The final Softmax is left out of the graph: the runtime takes the softmax of the two
logits when it reads the matte (`io.json` `matte`). `scripts/convert-matting-models.py` of the gpufx repository
does all of it; `source.json` pins the file by sha256.

## Use

The frame is stretched to 256x144 (width x height, as PaddleSeg's deploy config), RGB normalized to [-1, 1]; the
output is the foreground probability at that size, which the runtime resizes to the frame. Portrait (vertical)
frames are stretched too.

## License

See the `LICENSE` file in this package (Apache License 2.0, the license of PaddleSeg and its released models).
Read it before redistributing the package.
