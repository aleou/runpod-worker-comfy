# --------------------------------------------------------
# Stage 1: Base image with common dependencies
# --------------------------------------------------------
  FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04 as base

  # Prevent interactive prompts during installation
  ENV DEBIAN_FRONTEND=noninteractive
  ENV PIP_PREFER_BINARY=1
  ENV PYTHONUNBUFFERED=1
  ENV CMAKE_BUILD_PARALLEL_LEVEL=8
  
  # Increase polling timeout for long video processing jobs (10 minutes = 2400 retries * 250ms)
  ENV COMFY_POLLING_MAX_RETRIES=2400
  ENV COMFY_POLLING_INTERVAL_MS=250
  
  # au lieu d’installer python3.10
  RUN apt-get update && apt-get install -y git wget aria2 libgl1 vim curl ca-certificates libcudnn8 libcudnn8-dev \
  && rm -rf /var/lib/apt/lists/*

  RUN pip install --upgrade pip comfy-cli
  
  # Install ComfyUI
  RUN bash -lc 'set +o pipefail; printf "%s\n" n y | comfy --workspace /comfyui install --nvidia --version 0.3.65; exit ${PIPESTATUS[1]}'
  RUN comfy tracking disable
  
  # Change working directory to ComfyUI
  WORKDIR /comfyui
  
  # Install runpod dependencies
  RUN pip install runpod requests
  
  # Clone custom node repository at specific commit
  RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git custom_nodes/ComfyUI-WanVideoWrapper \
  && cd custom_nodes/ComfyUI-WanVideoWrapper \
  && git checkout b52e5b92bdc218ecb6e959a5d568eb46c0bae41d
  
  # Support for the network volume
  ADD src/extra_model_paths.yaml ./
  
  # Go back to the root
  WORKDIR /
  
  # Add scripts
  ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
  RUN chmod +x /start.sh /restore_snapshot.sh
  
  ARG MODEL_TYPE
  # Copie tous les snapshots dans l'image
  COPY snapshots/ /snapshots/

  # Sélectionne le bon snapshot et restaure
  RUN set -eux; \
      MODEL_TYPE_VALUE="${MODEL_TYPE:-}"; \
      if [ -z "$MODEL_TYPE_VALUE" ]; then \
        echo "MODEL_TYPE non defini, restauration du snapshot ignoree pour l'image base"; \
      else \
        SNAP="/snapshots/snapshot-${MODEL_TYPE_VALUE}.json"; \
        test -f "$SNAP" || { echo "Snapshot introuvable pour MODEL_TYPE=${MODEL_TYPE_VALUE} -> $SNAP"; exit 1; }; \
        cp "$SNAP" /snapshot.json; \
        /restore_snapshot.sh; \
      fi
  
  # Après l'installation de comfy-cli et avant la restauration du snapshot
  RUN pip uninstall -y opencv-contrib-python opencv-contrib-python-headless opencv-python opencv-python-headless || true \
  && pip install opencv-contrib-python-headless scikit-image diffusers accelerate imageio-ffmpeg color-matcher sageattention segment_anything piexif ultralytics ftfy dill
  # By default, start container
  CMD ["/start.sh"]

  
  # --------------------------------------------------------
  # Stage 2: Download models
  # --------------------------------------------------------
  FROM base as downloader
  
  ARG HUGGINGFACE_ACCESS_TOKEN
  ARG MODEL_TYPE

  WORKDIR /comfyui
  
  # Create necessary directories for models
  RUN mkdir -p models/loras models/checkpoints models/vae models/text_encoders models/diffusion_models models/clip models/clip_vision models/upscale_models models/diffueraser models/DiffuEraser/diffueraser models/DiffuEraser/propainter
  
    # Download WAN 2.1 if MODEL_TYPE = Wan
    RUN if [ "$MODEL_TYPE" = "flux1-dev" ]; then \
    aria2c -x16 -s16 -d models/vae -o ae.safetensors \
    https://huggingface.co/lovis93/testllm/resolve/ed9cf1af7465cebca4649157f118e331cf2a084f/ae.safetensors & \
    aria2c -x16 -s16 -d models/diffusion_models -o flux1-dev-Q5_K_S.gguf \
      https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q5_K_S.gguf & \
    aria2c -x16 -s16 -d models/clip -o t5-v1_1-xxl-encoder-Q5_K_S.gguf \
      https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q5_K_S.gguf & \
    aria2c -x16 -s16 -d models/clip -o ViT-L-14-TEXT-detail-improved-hiT-GmP-TE-only-HF.safetensors \
      https://huggingface.co/zer0int/CLIP-GmP-ViT-L-14/resolve/main/ViT-L-14-TEXT-detail-improved-hiT-GmP-TE-only-HF.safetensors & \
    aria2c -x16 -s16 -d models/upscale_models -o 4x_foolhardy_Remacri.pth \
      https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth & \
    aria2c -x16 -s16 -d models/upscale_models -o 4x_NMKD-Siax_200k.pth \
      https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Siax_200k.pth & \
    wait; \
  fi

    RUN if [ "$MODEL_TYPE" = "Qwen-image" ]; then \
    aria2c -x16 -s16 -d models/vae -o qwen_image_vae.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors & \
    aria2c -x16 -s16 -d models/diffusion_models -o qwen-image-Q8_0.gguf \
      https://huggingface.co/city96/Qwen-Image-gguf/resolve/main/qwen-image-Q8_0.gguf & \
    aria2c -x16 -s16 -d models/clip -o Qwen2.5-VL-7B-Instruct-UD-Q8_K_XL.gguf \
      https://huggingface.co/unsloth/Qwen2.5-VL-7B-Instruct-GGUF/resolve/main/Qwen2.5-VL-7B-Instruct-UD-Q8_K_XL.gguf & \
    aria2c -x16 -s16 -d models/upscale_models -o 4x_foolhardy_Remacri.pth \
      https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth & \
    aria2c -x16 -s16 -d models/upscale_models -o 4x_NMKD-Siax_200k.pth \
      https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Siax_200k.pth & \
    wait; \
  fi
  
  # Download WAN 2.1 if MODEL_TYPE = Wan
  RUN if [ "$MODEL_TYPE" = "Wan" ]; then \
      aria2c -x16 -s16 -d models/vae -o wan_2.1_vae.safetensors \
        https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors & \
      aria2c -x16 -s16 -d models/diffusion_models -o wan2.1-i2v-14b-720p-Q5_K_M.gguf \
        https://huggingface.co/city96/Wan2.1-I2V-14B-720P-gguf/resolve/main/wan2.1-i2v-14b-720p-Q5_K_M.gguf & \
      aria2c -x16 -s16 -d models/diffusion_models -o wan2.1-i2v-14b-480p-Q5_K_M.gguf \
        https://huggingface.co/city96/Wan2.1-I2V-14B-480P-gguf/resolve/main/wan2.1-i2v-14b-480p-Q5_K_M.gguf & \
      aria2c -x16 -s16 -d models/clip_vision -o clip_vision_h.safetensors \
        https://huggingface.co/calcuis/wan-gguf/resolve/ff59c62b6a008bc99677228596e096130066b234/clip_vision_h.safetensors & \
      aria2c -x16 -s16 -d models/clip -o umt5_xxl_fp8_e4m3fn_scaled.safetensors \
      https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors & \
      aria2c -x16 -s16 -d models/clip -o open-clip-xlm-roberta-large-vit-huge-14_visual_fp32.safetensors \
        https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/open-clip-xlm-roberta-large-vit-huge-14_visual_fp32.safetensors & \
      aria2c -x16 -s16 -d models/upscale_models -o 4x_foolhardy_Remacri.pth \
        https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth & \
      wait; \
    fi
  # Download Hunyuhan models if MODEL_TYPE = Hunyuhan https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_FastVideo_720_fp8_e4m3fn.safetensors
  RUN if [ "$MODEL_TYPE" = "Hunyuhan" ]; then \
    aria2c -x16 -s16 -d models/diffusion_models -o hunyuan_video_I2V_720_fixed_bf16.safetensors \
      https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_I2V_720_fixed_bf16.safetensors & \
    aria2c -x16 -s16 -d models/diffusion_models -o hunyuan_video_FastVideo_720_fp8_e4m3fn.safetensors \
      https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_FastVideo_720_fp8_e4m3fn.safetensors & \
    aria2c -x16 -s16 -d models/loras -o HunyuanVideo_dashtoon_keyframe_lora_converted_comfy_bf16.safetensors \
      https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/HunyuanVideo_dashtoon_keyframe_lora_converted_comfy_bf16.safetensors & \
    aria2c -x16 -s16 -d models/vae -o hunyuan_video_vae_bf16.safetensors \
      https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_vae_bf16.safetensors & \
    aria2c -x16 -s16 -d models/clip -o clip_l.safetensors \
      https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors & \
    aria2c -x16 -s16 -d models/clip -o llava_llama3_fp8_scaled.safetensors \
      https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/llava_llama3_fp8_scaled.safetensors & \
    wait; \
  fi
  
  # Download upscale models if MODEL_TYPE = upscale
  RUN if [ "$MODEL_TYPE" = "upscale" ]; then \
    aria2c -x16 -s16 -d models/upscale_models -o 4x_foolhardy_Remacri.pth \
      https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth & \
    aria2c -x16 -s16 -d models/upscale_models -o 4x_NMKD-Siax_200k.pth \
      https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Siax_200k.pth & \
    aria2c -x16 -s16 -d models/upscale_models -o 2x-AnimeSharpV4_Fast_RCAN_PU.safetensors \
      https://github.com/Kim2091/Kim2091-Models/releases/download/2x-AnimeSharpV4/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors & \
    aria2c -x16 -s16 -d models/upscale_models -o RealESRGAN_x2plus.pth \
      https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth & \
    aria2c -x16 -s16 -d models/upscale_models -o 2xNomosUni_esrgan_multijpg.pth \
      https://huggingface.co/Kyca/KycasFiles/resolve/main/2xNomosUni_esrgan_multijpg.pth & \
    wait; \
  fi

  # Download watermark models if MODEL_TYPE = watermark
  RUN if [ "$MODEL_TYPE" = "watermark" ]; then \
    aria2c -x16 -s16 -d models/loras -o pcm_sd15_smallcfg_2step_converted.safetensors \
      https://huggingface.co/wangfuyun/PCM_Weights/resolve/main/sd15/pcm_sd15_smallcfg_2step_converted.safetensors & \
    aria2c -x16 -s16 -d models/checkpoints -o realisticVisionV51_v51VAE.safetensors \
      https://huggingface.co/lllyasviel/fav_models/resolve/main/fav/realisticVisionV51_v51VAE.safetensors & \
    aria2c -x16 -s16 -d models/DiffuEraser/diffueraser -o diffusion_pytorch_model.safetensors \
      https://huggingface.co/lixiaowen/diffuEraser/resolve/main/brushnet/diffusion_pytorch_model.safetensors & \
    aria2c -x16 -s16 -d models/DiffuEraser/propainter -o raft-things.pth \
      https://github.com/sczhou/ProPainter/releases/download/v0.1.0/raft-things.pth & \
    aria2c -x16 -s16 -d models/DiffuEraser/propainter -o recurrent_flow_completion.pth \
      https://github.com/sczhou/ProPainter/releases/download/v0.1.0/recurrent_flow_completion.pth & \
    aria2c -x16 -s16 -d models/DiffuEraser/propainter -o ProPainter.pth \
      https://github.com/sczhou/ProPainter/releases/download/v0.1.0/ProPainter.pth & \
    wait; \
  fi
  
  
  # --------------------------------------------------------
  # Stage 3: Final image
  # --------------------------------------------------------
  FROM base as final
  
  ARG MODEL_TYPE
  
  # Copy models from stage 2 to the final image
  COPY --from=downloader /comfyui/models /comfyui/models


  # ------------ correctif SSL pour Let’s Encrypt R11 ----------
  RUN pip install --no-cache-dir --upgrade certifi urllib3 botocore boto3 awscli soundfile
  # ------------------------------------------------------------
  
  # Final command
  CMD ["/start.sh"]
  
