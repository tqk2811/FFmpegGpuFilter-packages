# yunet-2023mar

YuNet, a small face detector, as a gpufx-nn model package for the automatic face censor of the gpufx editor
(`gpufx_ai_tracking`, `FaceDetector` of gpufx-core).

## Source

The model is `face_detection_yunet_2023mar.onnx` of [OpenCV Zoo](https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet)
(by Shiqi Yu and others, trained with [libfacedetection.train](https://github.com/ShiqiYu/libfacedetection.train)),
pinned at commit `eb9f4f2d`. `scripts/convert-tracking-models.py` of the gpufx repository cuts the graph before
the reshapes of its outputs (the landmark branch is dropped), converts it to ncnn by pnnx with f32 weights and
to gpufx-nn by `gpufx-nnconv`. `source.json` pins every file by sha256.

## Use

- Input `in0`: the frame, 3 x H x W, BGR values in [0, 255], no normalisation; H and W are multiples of 32
  (the frame is scaled so its long side is `input_size`, then padded with zeros at the right and bottom).
- Outputs, per stride 8, 16 and 32 (`heads` of `io.json`): `cls` and `obj`, 1 x H/s x W/s logits, and `bbox`,
  4 x H/s x W/s. The score of cell (r, c) is `sqrt(sigmoid(cls) * sigmoid(obj))`; its box has the centre
  `((c + bbox0) * s, (r + bbox1) * s)` and the size `(exp(bbox2) * s, exp(bbox3) * s)` in input pixels.
- Boxes above `score_threshold` go through non-maximum suppression at `nms_threshold` (IoU).

## License

See the `LICENSE` file inside the package zip (put there with the model by the conversion script, not kept in
this folder; MIT License, Copyright (c) 2020 Shiqi Yu, which OpenCV Zoo states covers every file of the model's
folder, the ONNX weights included). Read it before redistributing the package.
