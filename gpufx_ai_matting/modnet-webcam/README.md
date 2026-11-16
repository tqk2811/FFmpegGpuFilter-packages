# modnet-webcam

MODNet (webcam portrait matting) as a gpufx-nn package (`io.json` kind `matting`), for background removal with
`gpufx_ai_matting` / `FrameMatte` of the gpufx project. Higher quality of the two matting packages: a soft alpha
(the graph ends in a sigmoid) at about 512 pixels on the short side.

## Source

The weights are the `modnet_webcam_portrait_matting.ckpt` checkpoint of
[MODNet](https://github.com/ZHKKKe/MODNet) (MODNet: Real-Time Trimap-Free Portrait Matting via Objective
Decomposition, Ke et al., AAAI 2022), downloaded from the Intel OpenVINO Open Model Zoo mirror (the original is on
Google Drive), exported to ONNX with the repository's `onnx/modnet_onnx.py`, converted to ncnn by pnnx with f32
weights and to gpufx-nn by `gpufx-nnconv`. `scripts/convert-matting-models.py` of the gpufx repository does all of
it; `source.json` pins every file by sha256.

## Use

The frame is scaled so its short side is 512 and each side rounded to a multiple of 32 (the aspect ratio kept up
to that rounding), RGB normalized to [-1, 1]; the output is the alpha at that size, which the runtime resizes to
the frame.

## License

See the `LICENSE` file in this package (Apache License 2.0, the license of the MODNet repository and its
pre-trained models). Read it before redistributing the package.
