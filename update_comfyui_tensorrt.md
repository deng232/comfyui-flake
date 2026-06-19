# Task: Modernize `ComfyUI_TensorRT` for current ComfyUI/PyTorch, SDXL static/dynamic first

## Goal

Create a maintained-quality fork/patch of `ComfyUI_TensorRT` that works with current ComfyUI and current PyTorch for **SDXL-family models**, including SDXL derivatives such as Illustrious / WAI-illustrious.

For now, the required supported test matrix is only:

| Model family                         | Static engine | Dynamic engine |
| ------------------------------------ | ------------: | -------------: |
| SDXL / Illustrious / WAI-illustrious |           yes |            yes |

Do **not** implement or claim support for SD1.5, SD2, SD3, Flux, AuraFlow, SVD, SVD-XT, video, ControlNet, IPAdapter, or LoRA runtime switching in this task. Keep the code structured so those can be added later, but only SDXL static/dynamic must pass now.

## Problems to fix

There are two independent breakages with current ComfyUI/PyTorch.

### 1. ComfyUI DynamicVRAM / `force_patch_weights` incompatibility

The existing TensorRT converter calls something equivalent to:

```python
comfy.model_management.load_models_gpu(
    [model],
    force_patch_weights=True,
    force_full_load=True,
)
```

Current ComfyUI may provide a DynamicVRAM `ModelPatcherDynamic`, whose `partially_load()` path asserts:

```python
assert not force_patch_weights
```

The TensorRT exporter needs a fully materialized non-dynamic model for ONNX/TensorRT export. Fix this by converting dynamic model patchers to a non-dynamic delegate before forced full load.

Expected pattern:

```python
comfy.model_management.unload_all_models()

if hasattr(model, "get_non_dynamic_delegate"):
    model = model.get_non_dynamic_delegate()

comfy.model_management.load_models_gpu(
    [model],
    force_patch_weights=True,
    force_full_load=True,
)
```

Do not simply set `force_patch_weights=False` as the main fix. The exporter should materialize patched weights before exporting.

### 2. PyTorch ONNX exporter API mismatch

The existing code uses old `torch.onnx.export(..., dynamic_axes=...)` behavior and does not pass `dynamo=` explicitly.

In PyTorch 2.9+, `torch.onnx.export` defaults to `dynamo=True`, which uses the new `torch.export`-based exporter. The old code’s generic `*args` wrapper and `dynamic_axes` usage can fail with errors like:

```text
Detected mismatch between the structure of inputs and dynamic_shapes:
inputs[3] is a tuple, but dynamic_shapes[3] is a dict
```

For this maintained fork, implement a clean SDXL export path instead of relying on the stale generic `*args` path.

## Required design

Refactor the export code so SDXL has an explicit export adapter/wrapper.

### SDXL wrapper

Create an explicit SDXL UNet wrapper with a stable forward signature:

```python
class SDXLUNetExportWrapper(torch.nn.Module):
    def __init__(self, unet, transformer_options=None):
        super().__init__()
        self.unet = unet
        self.transformer_options = transformer_options or {}

    def forward(self, x, timesteps, context, y):
        return self.unet(
            x,
            timesteps,
            context,
            y=y,
            transformer_options=self.transformer_options,
        )
```

Do not pass SDXL `y` through `*args`. The exporter input structure must be:

```python
(x, timesteps, context, y)
```

not:

```python
(x, timesteps, context, (y,))
```

### Static SDXL export

For static export, do not pass dynamic shape metadata.

Static means:

```text
batch_size_min = batch_size_opt = batch_size_max
height_min = height_opt = height_max
width_min = width_opt = width_max
context_min = context_opt = context_max
```

For static ONNX export, use the exact example input shapes and omit both:

```python
dynamic_axes
dynamic_shapes
```

The static exporter should call:

```python
torch.onnx.export(
    export_wrapper,
    inputs,
    output_onnx,
    input_names=["x", "timesteps", "context", "y"],
    output_names=["out"],
    opset_version=18,
    dynamo=<selected_mode>,
    external_data=True,
)
```

For first reliable implementation, support a compatibility option that can force:

```python
dynamo=False
```

This preserves the old ONNX exporter path and is likely needed for compatibility with existing TensorRT parser behavior. But the code should be structured so `dynamo=True` can be selected/tested.

Acceptance criteria for static mode:

```text
No dynamic_axes passed.
No dynamic_shapes passed.
No *args wrapper.
unet/export_wrapper is in eval mode.
Export uses torch.inference_mode().
TensorRT optimization profile uses min=opt=max.
```

### Dynamic SDXL export

For dynamic export, support two exporter modes:

1. Legacy mode:

```python
dynamo=False
dynamic_axes=...
```

2. Modern mode:

```python
dynamo=True
dynamic_shapes=...
```

The code should default to the most reliable mode for TensorRT engine building, but both paths should be clearly implemented and selectable/configurable.

For legacy dynamic export, use:

```python
dynamic_axes = {
    "x": {0: "batch", 2: "height", 3: "width"},
    "timesteps": {0: "batch"},
    "context": {0: "batch", 1: "num_embeds"},
    "y": {0: "batch"},
    "out": {0: "batch", 2: "height", 3: "width"},
}
```

For modern dynamic export, use `torch.export.Dim` and make the structure match the actual input tuple:

```python
from torch.export import Dim

batch = Dim("batch", min=batch_size_min, max=batch_size_max)
latent_h = Dim("latent_h", min=height_min // 8, max=height_max // 8)
latent_w = Dim("latent_w", min=width_min // 8, max=width_max // 8)
tokens = Dim("tokens", min=77 * context_min, max=77 * context_max)

dynamic_shapes = (
    {0: batch, 2: latent_h, 3: latent_w},  # x
    {0: batch},                            # timesteps
    {0: batch, 1: tokens},                 # context
    {0: batch},                            # y
)
```

If PyTorch rejects the symbolic token dimension or TensorRT cannot parse the resulting ONNX, keep legacy dynamic export as the default and document the reason in code comments.

Acceptance criteria for dynamic mode:

```text
Legacy dynamic mode works with dynamo=False + dynamic_axes.
Modern dynamic mode does not use *args and uses input-structure-matching dynamic_shapes.
TensorRT profile uses min/opt/max shapes consistent with ONNX dynamic dimensions.
SDXL y/ADM input has correct batch dimension.
```

## Exporter options

Add an explicit exporter option in the TensorRT conversion node or internal config:

```text
onnx_exporter:
  legacy
  modern
  auto
```

Suggested behavior:

```text
legacy:
  torch.onnx.export(..., dynamo=False)
  dynamic mode uses dynamic_axes

modern:
  torch.onnx.export(..., dynamo=True)
  dynamic mode uses dynamic_shapes

auto:
  static: prefer legacy initially for TensorRT compatibility
  dynamic: prefer legacy initially for TensorRT compatibility
  log which mode was selected
```

Do not rely on PyTorch’s default `dynamo` value. Always pass `dynamo=True` or `dynamo=False` explicitly.

## Model detection

Implement an SDXL-only detector for this task.

The detector should recognize SDXL-family models by the presence of the SDXL `y` / ADM conditioning dimension used by the existing converter. Do not hardcode model filenames.

For non-SDXL models, fail clearly:

```text
Only SDXL-family TensorRT export is supported by this fork currently.
Detected unsupported model type: <type/details>
```

Do not silently try the old generic code path for unsupported models.

## Engine build profiles

Keep TensorRT optimization profile generation consistent with export mode.

For SDXL:

```text
x:
  shape = [batch, 4, height/8, width/8]

timesteps:
  shape = [batch]

context:
  shape = [batch, 77 * context, context_dim]

y:
  shape = [batch, y_dim]
```

For static:

```text
min = opt = max
```

For dynamic:

```text
min = user min
opt = user opt
max = user max
```

Validate before export:

```text
height and width must be divisible by 8.
min <= opt <= max for batch, height, width, context.
batch must be >= 1.
context must be >= 1.
SDXL y_dim must be > 0.
```

Fail early with human-readable errors.

## Runtime behavior

Before export:

```python
export_wrapper.eval()
```

Use:

```python
with torch.inference_mode():
    ...
```

After export/build, clean up GPU memory where appropriate:

```python
comfy.model_management.unload_all_models()
comfy.model_management.soft_empty_cache()
```

Do not leave the export wrapper in a state that breaks later ComfyUI execution.

## Logging

Add clear logs for:

```text
detected model family
exporter mode: legacy / modern
static or dynamic export
input shapes min/opt/max
ONNX output path
TensorRT engine output path
TensorRT version if available
PyTorch version
CUDA availability
```

When using legacy exporter, log:

```text
Using legacy ONNX exporter: torch.onnx.export(..., dynamo=False)
```

When using modern exporter, log:

```text
Using modern ONNX exporter: torch.onnx.export(..., dynamo=True)
```

## Test matrix

Only this matrix is required for now:

| Test                                     | Model                         | Engine type |                                Resolution | Batch | Context |
| ---------------------------------------- | ----------------------------- | ----------- | ----------------------------------------: | ----: | ------: |
| SDXL static square                       | SDXL-family / WAI-illustrious | static      |                                 1024x1024 |     1 |       1 |
| SDXL dynamic square range                | SDXL-family / WAI-illustrious | dynamic     | min 768x768, opt 1024x1024, max 1024x1024 |     1 |       1 |
| SDXL dynamic portrait/landscape optional | SDXL-family / WAI-illustrious | dynamic     | min 832x832, opt 1024x1024, max 1216x1216 |     1 |       1 |

Required pass criteria:

```text
ONNX export succeeds.
TensorRT engine build succeeds.
Engine appears in ComfyUI TensorRT model path or output path.
TensorRT loader can load engine.
A simple txt2img workflow can run one image.
No force_patch_weights assertion.
No torch.export dynamic_shapes/input-structure mismatch.
No training-mode export warning.
```

## Non-GPU tests

Add lightweight unit tests or script-level tests for shape/profile generation that do not require TensorRT:

```text
static SDXL profile has min=opt=max
dynamic SDXL profile has min<=opt<=max
height/width validation catches non-divisible-by-8 values
SDXL wrapper forward signature is explicit: x, timesteps, context, y
legacy exporter config omits dynamic_axes for static export
modern exporter config omits dynamic_shapes for static export
dynamic exporter config includes correct dynamic metadata only for dynamic export
```

These tests can be simple Python tests under a `tests/` directory or a standalone script if the project currently has no test framework.

## Manual GPU test script

Add a `docs/testing-sdxl.md` or `scripts/test_sdxl_export.md` describing how to test manually inside ComfyUI.

Include:

```text
1. Start ComfyUI with current fork installed.
2. Load SDXL-family checkpoint.
3. Run Static Model TensorRT Conversion:
   batch_size_opt = 1
   height_opt = 1024
   width_opt = 1024
   context_opt = 1
4. Confirm ONNX and engine are generated.
5. Run TensorRT Loader with generated engine.
6. Generate one 1024x1024 image.
7. Repeat with Dynamic Model TensorRT Conversion:
   batch_size_min = 1
   batch_size_opt = 1
   batch_size_max = 1
   height_min = 768
   height_opt = 1024
   height_max = 1024
   width_min = 768
   width_opt = 1024
   width_max = 1024
   context_min = 1
   context_opt = 1
   context_max = 1
```

Also include a troubleshooting section for:

```text
TensorRT parser errors
ONNX export errors
VRAM OOM
unsupported ops
engine load failure
ComfyUI DynamicVRAM issues
```

## Compatibility policy

For this task:

```text
Must support current ComfyUI DynamicVRAM without crashing.
Must support PyTorch where torch.onnx.export defaults to dynamo=True.
Must explicitly pass dynamo=True or dynamo=False.
Must not rely on old PyTorch defaults.
Must not silently export training-mode modules.
Must not claim support for LoRA/ControlNet unless specifically tested.
```

## Code quality requirements

Do not add one-off hacks directly inside a huge conversion function if avoidable. Prefer small helpers/classes:

```text
SDXLUNetExportWrapper
ExportMode enum or constants
build_sdxl_example_inputs(...)
build_sdxl_dynamic_axes(...)
build_sdxl_dynamic_shapes(...)
build_sdxl_trt_profile(...)
validate_sdxl_shape_config(...)
prepare_model_for_export(...)
```

The conversion function should read like:

```python
model = prepare_model_for_export(model)
adapter = detect_export_adapter(model)
inputs = adapter.make_example_inputs(...)
export_config = adapter.make_export_config(...)
export_onnx(adapter.wrapper, inputs, export_config)
build_engine_from_onnx(...)
```

Keep compatibility with existing node UI as much as possible. If adding new UI options, make defaults safe.

## Deliverables

1. Patch/fork code implementing SDXL static/dynamic TensorRT export.
2. Explicit DynamicVRAM compatibility fix.
3. Explicit ONNX exporter mode handling.
4. Static export path that does not pass dynamic metadata.
5. Dynamic export path with legacy and modern implementations where possible.
6. SDXL-specific explicit wrapper, no `*args` for SDXL export.
7. Shape/profile validation with readable errors.
8. Logging of exporter mode, shapes, versions, and output paths.
9. Non-GPU tests for shape/profile/export config generation.
10. Manual GPU test documentation for SDXL static/dynamic.

## Do not do in this task

Do not implement broad model support yet.

Specifically do not implement:

```text
SD1.5
SD2
SD3
Flux
AuraFlow
SVD/SVD-XT
Wan video
ControlNet
IPAdapter
LoRA switching after engine build
quantization
NVIDIA ModelOpt
Torch-TensorRT dynamo.compile route
```

Do not replace the whole project with a different TensorRT framework. This task is specifically to make the existing ComfyUI TensorRT custom node maintainable for SDXL static/dynamic export first.

## Final acceptance checklist

Before considering the task complete, confirm:

```text
[ ] SDXL static ONNX export succeeds.
[ ] SDXL static TensorRT engine build succeeds.
[ ] SDXL static engine loads and runs in ComfyUI.
[ ] SDXL dynamic ONNX export succeeds.
[ ] SDXL dynamic TensorRT engine build succeeds.
[ ] SDXL dynamic engine loads and runs in ComfyUI.
[ ] No force_patch_weights assertion occurs.
[ ] No torch.export dynamic_shapes/input mismatch occurs.
[ ] No training-mode ONNX export warning occurs.
[ ] Exporter mode is explicit in code and logs.
[ ] Static export does not pass dynamic_axes or dynamic_shapes.
[ ] Dynamic export passes correct dynamic metadata for selected exporter mode.
[ ] Unsupported model families fail with clear errors.
[ ] Test/documentation files are added.
```
