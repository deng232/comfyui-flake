{
  lib,
  fetchPypi,
  makeWrapper,
  python3Packages,
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
    }:
    py.buildPythonPackage {
      inherit
        pname
        version
        dependencies
        pythonImportsCheck
        ;

      format = "wheel";

      src = fetchPypi {
        inherit pname version hash;
        format = "wheel";
        dist = "py3";
        python = "py3";
        abi = "none";
        platform = "any";
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
    hash = "sha256-wkKv0Y0SDij8lJxCP6KMuyLLTXDWJ9jMfN9rrVTdJyw=";
  };

  comfy-aimdo = py3Wheel {
    pname = "comfy_aimdo";
    version = "0.4.9";
    hash = "sha256-qCF8CXnW5AJU/civJnCxjZxOmfPFRp7wmv8UbDaD7y8=";
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

    src = ./ComfyUI;

    nativeBuildInputs = [
      makeWrapper
    ];

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

      makeWrapper ${py.python.interpreter} "$out/bin/comfyui" \
        --add-flags "$appdir/main.py" \
        --set PYTHONPATH "$appdir:${py.makePythonPath pythonPath}" \
        --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib"

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
