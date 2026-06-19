it was probably an corss verions issue https://github.com/comfyanonymous/ComfyUI_TensorRT has no patch
for two years.





[ERROR] !!! Exception during processing !!!
  [ERROR] Traceback (most recent call last):
    File "/nix/store/i5wz62a770agp74xw9xg4f7b485f2z9x-comfyui-local/share/comfyui/execution.py", line 542, in execute
      output_data, output_ui, has_subgraph, has_pending_tasks = await get_output_data(prompt_id, unique_id, obj, input_data_all,
  execution_block_cb=execution_block_cb, pre_execute_cb=pre_execute_cb, v3_data=v3_data)

  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^
    File "/nix/store/i5wz62a770agp74xw9xg4f7b485f2z9x-comfyui-local/share/comfyui/execution.py", line 341, in get_output_data
      return_values = await _async_map_node_over_list(prompt_id, unique_id, obj, input_data_all, obj.FUNCTION,
  allow_interrupt=True, execution_block_cb=execution_block_cb, pre_execute_cb=pre_execute_cb, v3_data=v3_data)

  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    File "/nix/store/i5wz62a770agp74xw9xg4f7b485f2z9x-comfyui-local/share/comfyui/execution.py", line 315, in
  _async_map_node_over_list
      await process_inputs(input_dict, i)
    File "/nix/store/i5wz62a770agp74xw9xg4f7b485f2z9x-comfyui-local/share/comfyui/execution.py", line 303, in process_inputs
      result = f(**inputs)
    File "/home/deng/comfy/workdir/custom_nodes/ComfyUI_TensorRT/tensorrt_convert.py", line 627, in convert
      return super()._convert(
             ~~~~~~~~~~~~~~~~^
          model,
          ^^^^^^
      ...<14 lines>...
          is_static=True,
          ^^^^^^^^^^^^^^^
      )
      ^
    File "/home/deng/comfy/workdir/custom_nodes/ComfyUI_TensorRT/tensorrt_convert.py", line 158, in _convert
      comfy.model_management.load_models_gpu([model], force_patch_weights=True, force_full_load=True)
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    File "/nix/store/i5wz62a770agp74xw9xg4f7b485f2z9x-comfyui-local/share/comfyui/comfy/model_management.py", line 944, in
  load_models_gpu
      loaded_model.model_load(lowvram_model_memory, force_patch_weights=force_patch_weights)
      ~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    File "/home/deng/comfy/workdir/custom_nodes/comfyui-benchmark/__init__.py", line 334, in wrapper_LoadedModel_model_load
      return func(*args, **kwargs)
    File "/nix/store/i5wz62a770agp74xw9xg4f7b485f2z9x-comfyui-local/share/comfyui/comfy/model_management.py", line 732, in
  model_load
      self.model_use_more_vram(use_more_vram, force_patch_weights=force_patch_weights)
      ~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    File "/nix/store/i5wz62a770agp74xw9xg4f7b485f2z9x-comfyui-local/share/comfyui/comfy/model_management.py", line 760, in
  model_use_more_vram
      return self.model.partially_load(self.device, extra_memory, force_patch_weights=force_patch_weights)
             ~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    File "/nix/store/i5wz62a770agp74xw9xg4f7b485f2z9x-comfyui-local/share/comfyui/comfy/model_patcher.py", line 2016, in
  partially_load
      assert not force_patch_weights #See above
             ^^^^^^^^^^^^^^^^^^^^^^^
  AssertionError
  while building the tensorrt model in the comfyui


# ComfyUI TensorRT Conversion AssertionError

Date: 2026-06-18

## Summary

TensorRT model conversion failed while `ComfyUI_TensorRT` was trying to load the source model onto the GPU before ONNX/TensorRT export.

The failure was not caused by a missing TensorRT dependency. It was an API compatibility issue between the local `ComfyUI_TensorRT` custom node and the current ComfyUI model loading implementation.

## Error

During TensorRT conversion, ComfyUI raised:

```text
AssertionError
```

The relevant stack path was:

```text
ComfyUI_TensorRT/tensorrt_convert.py
  comfy.model_management.load_models_gpu([model], force_patch_weights=True, force_full_load=True)

ComfyUI/comfy/model_management.py
  loaded_model.model_load(lowvram_model_memory, force_patch_weights=force_patch_weights)

ComfyUI/comfy/model_patcher.py
  assert not force_patch_weights
```

## Cause

`ComfyUI_TensorRT` called:

```python
comfy.model_management.load_models_gpu(
    [model],
    force_patch_weights=True,
    force_full_load=True,
)
```

In the current ComfyUI codebase, the active `ModelPatcher.partially_load()` path explicitly rejects `force_patch_weights=True`:

```python
assert not force_patch_weights
```

So TensorRT conversion reached a ComfyUI code path where forced patching is no longer accepted.

## Fix Applied

Patched:

```text
workdir/custom_nodes/ComfyUI_TensorRT/tensorrt_convert.py
```

Changed:

```python
comfy.model_management.load_models_gpu([model], force_patch_weights=True, force_full_load=True)
```

to:

```python
comfy.model_management.load_models_gpu([model], force_full_load=True)
```

`force_full_load=True` is preserved so the model is still fully loaded for export. Only the incompatible `force_patch_weights=True` flag was removed.

## Why This Should Work

`force_full_load=True` asks ComfyUI to avoid low-VRAM partial loading for this conversion step.

Removing `force_patch_weights=True` avoids the assertion in the current dynamic patcher implementation while still letting ComfyUI load the model through its managed GPU-loading API.

## Related Dependency Notes

For the TensorRT custom node, the Python runtime needs:

```nix
onnx
tensorrt
```

The CUDA TensorRT runtime package should be exposed through runtime library paths, not `PYTHONPATH`:

```nix
extra_runtime_libs = [
  pkgs.cudaPackages.tensorrt
];
```

## Follow-Up Checks

After restarting ComfyUI, retry TensorRT conversion.

Useful checks:

```bash
./result/bin/python -c 'import tensorrt, onnx; print(tensorrt.__version__)'
```

If the assertion returns, search for remaining custom-node calls:

```bash
rg -n "force_patch_weights|load_models_gpu\\(" workdir/custom_nodes/ComfyUI_TensorRT
```

If TensorRT import fails instead, rebuild the Nix package and confirm `result/bin/comfyui` contains TensorRT and ONNX paths in `PYTHONPATH`.
