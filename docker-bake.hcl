variable "DOCKERHUB_REPO" {
  default = "aleou"
}

variable "DOCKERHUB_IMG" {
  default = "runpod-worker-comfy"
}

variable "RELEASE_VERSION" {
  default = "5.13"
}

variable "HUGGINGFACE_ACCESS_TOKEN" {
  default = ""
}

group "default" {
  targets = ["base", "sdxl", "sd3", "flux1-schnell", "flux1-dev","wan2-1","Qwen-image","hunyuan","upscale","watermark"]
}

target "base" {
  context = "."
  dockerfile = "Dockerfile"
  target = "base"
  platforms = ["linux/amd64"]
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:base-${RELEASE_VERSION}"]
}

target "sdxl" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "sdxl"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:sdxl-${RELEASE_VERSION}"]
  inherits = ["base"]
}

target "sd3" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "sd3"
    HUGGINGFACE_ACCESS_TOKEN = "${HUGGINGFACE_ACCESS_TOKEN}"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:sd3-${RELEASE_VERSION}"]
  inherits = ["base"]
}

target "flux1-schnell" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "flux1-schnell"
    HUGGINGFACE_ACCESS_TOKEN = "${HUGGINGFACE_ACCESS_TOKEN}"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:flux1-schnell-${RELEASE_VERSION}"]
  inherits = ["base"]
}

target "Qwen-image" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "Qwen-image"
    HUGGINGFACE_ACCESS_TOKEN = "${HUGGINGFACE_ACCESS_TOKEN}"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:Qwen-image-${RELEASE_VERSION}"]
  inherits = ["base"]
}

target "flux2-dev" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "flux2-dev"
    HUGGINGFACE_ACCESS_TOKEN = "${HUGGINGFACE_ACCESS_TOKEN}"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:flux2-dev-${RELEASE_VERSION}"]
  inherits = ["base"]
}

target "wan2-1" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "Wan"
    HUGGINGFACE_ACCESS_TOKEN = "${HUGGINGFACE_ACCESS_TOKEN}"
  }
  # Tag par exemple : <repo>/<img>:wan2.1-3.4.0
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:wan2.1-${RELEASE_VERSION}"]
  inherits = ["base"]
}

target "hunyuan" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "Hunyuhan"
    HUGGINGFACE_ACCESS_TOKEN = "${HUGGINGFACE_ACCESS_TOKEN}"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:hunyuan-${RELEASE_VERSION}"]
  inherits = ["base"]
}

target "upscale" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "upscale"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:upscale-${RELEASE_VERSION}"]
  inherits = ["base"]
}

target "watermark" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "watermark"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:watermark-${RELEASE_VERSION}"]
  inherits = ["base"]
}

# MiniMax H3 : Dockerfile séparé (PyTorch cu130, ComfyUI 0.39.2, Veda), 9 modèles embarqués.
# Volontairement absent du groupe "default" : un build global ne doit pas lancer 65 Go de téléchargements.
variable "TORCH_VERSION" {
  default = "2.14.1"
}

variable "TORCHVISION_VERSION" {
  default = "0.29.1"
}

# Commit "release: 0.3.1" de veda-sparse/Veda-on-ComfyUI
variable "VEDA_COMMIT" {
  default = "8d7ac153ac215d636eaf1b5910b0536c3de9e6ed"
}

target "minimax-h3" {
  context = "."
  dockerfile = "Dockerfile.h3"
  platforms = ["linux/amd64"]
  args = {
    TORCH_VERSION = "${TORCH_VERSION}"
    TORCHVISION_VERSION = "${TORCHVISION_VERSION}"
    VEDA_COMMIT = "${VEDA_COMMIT}"
  }
  # Token HF facultatif, passé en secret BuildKit (jamais en ARG)
  secret = HUGGINGFACE_ACCESS_TOKEN != "" ? ["type=env,id=hf_token,env=HUGGINGFACE_ACCESS_TOKEN"] : []
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:minimax-h3-${RELEASE_VERSION}"]
}
