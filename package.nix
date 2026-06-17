{
  bash,
  coreutils,
  lib,
  fetchPypi,
  python3Packages,
  util-linux,
  comfyui-src,
}:

let
  py = python3Packages;

  py3Wheel =
    {
      pname,
      version,
      hash,
      dependencies ? [ ],
      pythonImportsCheck ? [ ],
      format ? "wheel",
      dist ? "py3",
      python ? "py3",
      abi ? "none",
      platform ? "any",
    }:
    py.buildPythonPackage {
      inherit
        pname
        version
        dependencies
        pythonImportsCheck
        format
        ;

      src = fetchPypi {
        inherit
          pname
          version
          hash
          format
          dist
          python
          abi
          platform
          ;
      };

      doCheck = false;
    };

  comfyui-frontend-package = py3Wheel {
    pname = "comfyui_frontend_package";
    version = "1.45.15";
    hash = "sha256-ZuVkB1F7l8gkD3qzEOBxkdzBlV+Y20uvsRbi9Ky3p+E=";
  };

  comfyui-embedded-docs = py3Wheel {
    pname = "comfyui_embedded_docs";
    version = "0.5.3";
    hash = "sha256-wfXtWmsRftqvjggAduAAJW8B4h7uqr/7V2Nzgecidi8=";
  };

  comfyui-workflow-templates-core = py3Wheel {
    pname = "comfyui_workflow_templates_core";
    version = "0.3.252";
    hash = "sha256-nJpDCxEHS+uilAbbeMPWbEZI2k+cJG4lc240MrE3j1Q=";
  };

  comfyui-workflow-templates-media-api = py3Wheel {
    pname = "comfyui_workflow_templates_media_api";
    version = "0.3.80";
    hash = "sha256-VdAIVnqCUcrAUK0gKLpMLynrmzcJO3VkqPms+8KZwy0=";
  };

  comfyui-workflow-templates-media-video = py3Wheel {
    pname = "comfyui_workflow_templates_media_video";
    version = "0.3.91";
    hash = "sha256-KHpSCLeT/AdyGr198KcxXxau9/JRs2uUUiZh/au79Lg=";
  };

  comfyui-workflow-templates-media-image = py3Wheel {
    pname = "comfyui_workflow_templates_media_image";
    version = "0.3.150";
    hash = "sha256-CDwnZ4TgwG3JNCfIuGk1dVXpreCzz7DROj0xoXUDqdA=";
  };

  comfyui-workflow-templates-media-other = py3Wheel {
    pname = "comfyui_workflow_templates_media_other";
    version = "0.3.217";
    hash = "sha256-IAHQ65okpx7dHi9osdWT/izaaprII3FIC3L9Mxih5Gw=";
  };

  comfyui-workflow-templates = py3Wheel {
    pname = "comfyui_workflow_templates";
    version = "0.9.98";
    hash = "sha256-0Y+JloDgrP9dNa2siARFoF5K1jCl6xTC0on3vSz6TKM=";

    dependencies = [
      comfyui-workflow-templates-core
      comfyui-workflow-templates-media-api
      comfyui-workflow-templates-media-video
      comfyui-workflow-templates-media-image
      comfyui-workflow-templates-media-other
    ];
  };

  comfy-kitchen = py3Wheel {
    pname = "comfy_kitchen";
    version = "0.2.10";
    hash = "sha256-VKZL9N3fBa1p9e73PXLKoyijMbeYpBmXVZpRWOYW2H8=";
    dist = "cp312";
    python = "cp312";
    abi = "abi3";
    platform = "manylinux_2_24_x86_64.manylinux_2_28_x86_64";
  };

  comfy-aimdo = py3Wheel {
    pname = "comfy_aimdo";
    version = "0.4.9";
    hash = "sha256-sDTD8L0JSCN8rBzGmToM0PJIIpdv1o7+OY39T5Xh6ow=";
    dist = "cp39";
    python = "cp39";
    abi = "abi3";
    platform = "manylinux2010_x86_64.manylinux2014_x86_64.manylinux_2_12_x86_64.manylinux_2_17_x86_64";
  };

  trampoline = py3Wheel {
    pname = "trampoline";
    version = "0.1.2";
    hash = "sha256-NsyaT/mBGEPRd/wOB0DvvX2jnq3+blDJ4pN8vAbYmdk=";
  };

  torchsde = py3Wheel {
    pname = "torchsde";
    version = "0.2.6";
    hash = "sha256-Gb9/8C7sfo5GuhzbSqD52xxR1JJSShaXUjS0Z/f8Rjs=";

    dependencies = [
      py.numpy
      py.scipy
      py.torch
      trampoline
    ];
  };

  simpleeval = py3Wheel {
    pname = "simpleeval";
    version = "1.0.5";
    hash = "sha256-wN5CqfeEm3vIxRM4KVNBEm8QOiqGvs7/66/ZOI48384=";
  };

  spandrel = py3Wheel {
    pname = "spandrel";
    version = "0.4.2";
    hash = "sha256-bJPj7L6w5Uj9LfRaYFRys0wWFCh8VrUbszze965SNbU=";

    dependencies = with py; [
      torch
      torchvision
      safetensors
      numpy
      einops
      typing-extensions
    ];
  };

  pythonPath =
    with py;
    [
      torch
      torchvision
      torchaudio

      numpy
      einops
      transformers
      tokenizers
      sentencepiece
      safetensors
      aiohttp
      yarl
      pyyaml
      pillow
      scipy
      tqdm
      psutil
      alembic
      sqlalchemy
      filelock
      av
      requests

      blake3
      kornia

      pydantic
      pydantic-settings
      pyopengl
      glfw
    ]
    ++ [
      simpleeval
      spandrel
      torchsde
      comfyui-frontend-package
      comfyui-workflow-templates
      comfyui-embedded-docs
      comfy-kitchen
      comfy-aimdo
    ];
in

py.buildPythonApplication.override
  {
    stdenv = py.torch.stdenv;
  }
  {
    pname = "comfyui";
    version = "local";

    pyproject = false;

    src = comfyui-src;

    dependencies = pythonPath;

    dontBuild = true;
    dontWrapPythonPrograms = true;
    doCheck = false;

    installPhase = ''
      runHook preInstall

      appdir="$out/share/comfyui"
      mkdir -p "$appdir" "$out/bin"

      cp -R . "$appdir"
      chmod -R u+w "$appdir"

      mkdir -p "$out/libexec"

      cat > "$out/libexec/comfyui-overlay-run" <<'EOF'
      #!${bash}/bin/bash
      set -euo pipefail

      mode="$1"
      shift

      appdir="@appdir@"

      # Persist ComfyUI's mutable project tree outside the immutable Nix output.
      if [ -z "''${COMFYUI_HOME:-}" ] && [ -z "''${XDG_DATA_HOME:-}" ] && [ -z "''${HOME:-}" ]; then
        echo "comfyui: set COMFYUI_HOME or HOME so overlay data has a writable location" >&2
        exit 1
      fi

      state_home="''${COMFYUI_HOME:-''${XDG_DATA_HOME:-$HOME/.local/share}/comfyui}"
      overlay_home="''${COMFYUI_OVERLAY_HOME:-$state_home/overlay}"
      upperdir="$overlay_home/upper"
      workdir="$overlay_home/work"
      merged="$overlay_home/root"

      ${coreutils}/bin/mkdir -p "$upperdir" "$workdir" "$merged"

      # An overlay upper/work pair cannot be safely shared by concurrent mounts.
      exec 9>"$overlay_home/lock"
      if ! ${util-linux}/bin/flock -n 9; then
        echo "comfyui: overlay root is already in use: $overlay_home" >&2
        exit 1
      fi

      # Seed writable upper directories for paths ComfyUI commonly mutates.
      for dir in input output temp user models custom_nodes; do
        ${coreutils}/bin/mkdir -p "$upperdir/$dir"
        ${coreutils}/bin/chmod u+rwx "$upperdir/$dir"
      done

      # Present the immutable installed app as a writable project root.
      if ! ${util-linux}/bin/mount -t overlay overlay \
        -o "lowerdir=$appdir,upperdir=$upperdir,workdir=$workdir" \
        "$merged"; then
        echo "comfyui: failed to mount overlayfs project root" >&2
        echo "comfyui: this requires unprivileged user namespaces and overlayfs mounts to be allowed" >&2
        exit 1
      fi

      # Keep the private mount namespace tidy when the wrapped process exits.
      cleanup() {
        ${util-linux}/bin/umount "$merged" 2>/dev/null || true
      }
      trap cleanup EXIT

      # Make imports resolve against the writable overlay before packaged deps.
      export COMFYUI_PROJECT_ROOT="$merged"
      export PYTHONPATH="$merged:${py.makePythonPath pythonPath}"
      export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

      cd "$merged"

      # Use the same overlay setup for both the app and the debug Python shell.
      case "$mode" in
        comfyui)
          ${py.python.interpreter} "$merged/main.py" "$@"
          ;;
        python)
          ${py.python.interpreter} "$@"
          ;;
        *)
          echo "comfyui: unknown overlay mode: $mode" >&2
          exit 2
          ;;
      esac
      EOF
      substituteInPlace "$out/libexec/comfyui-overlay-run" \
        --replace-fail "@appdir@" "$appdir"

      cat > "$out/bin/comfyui" <<'EOF'
      #!${bash}/bin/bash
      set -euo pipefail

      # Give ComfyUI a private mount namespace where overlayfs can shadow $out.
      exec ${util-linux}/bin/unshare \
        --user \
        --map-root-user \
        --mount \
        --propagation private \
        --fork \
        "@overlayRun@" comfyui "$@"
      EOF
      substituteInPlace "$out/bin/comfyui" \
        --replace-fail "@overlayRun@" "$out/libexec/comfyui-overlay-run"

      cat > "$out/bin/python" <<'EOF'
      #!${bash}/bin/bash
      set -euo pipefail

      # Run debugging Python with the same writable project root as ComfyUI.
      exec ${util-linux}/bin/unshare \
        --user \
        --map-root-user \
        --mount \
        --propagation private \
        --fork \
        "@overlayRun@" python "$@"
      EOF
      substituteInPlace "$out/bin/python" \
        --replace-fail "@overlayRun@" "$out/libexec/comfyui-overlay-run"

      chmod +x "$out/libexec/comfyui-overlay-run" "$out/bin/comfyui" "$out/bin/python"

      runHook postInstall
    '';

    meta = {
      description = "Node-based workflow UI for generative AI models";
      homepage = "https://github.com/comfy-org/comfyui";
      license = lib.licenses.gpl3Only;
      mainProgram = "comfyui";
      platforms = lib.platforms.linux;
    };
  }
