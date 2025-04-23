# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

  # Prevent interactive prompts during installation
  ENV DEBIAN_FRONTEND=noninteractive
  ENV PIP_PREFER_BINARY=1
  ENV PYTHONUNBUFFERED=1
  ENV CMAKE_BUILD_PARALLEL_LEVEL=8
  
  # Install Python, Git, etc.
  RUN apt-get update && apt-get install -y \
      python3.10 python3-pip git wget aria2 libgl1 vim curl ca-certificates libcudnn8 libcudnn8-dev \
      && ln -sf /usr/bin/python3.10 /usr/bin/python \
      && ln -sf /usr/bin/pip3 /usr/bin/pip \
      && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
  
  # Install comfy-cli
  RUN pip install comfy-cli
  
  # Install ComfyUI
  RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 12.4 --nvidia --version 0.3.29
  
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
  
  # Optionally copy the snapshot file
  ADD *snapshot*.json /
  
  # Restore the snapshot to install custom nodes
  RUN /restore_snapshot.sh
  
  # Après l'installation de comfy-cli et avant la restauration du snapshot
  RUN pip uninstall -y opencv-contrib-python opencv-contrib-python-headless opencv-python opencv-python-headless || true \
  && pip install opencv-contrib-python-headless scikit-image diffusers accelerate imageio-ffmpeg color-matcher sageattention segment_anything piexif ultralytics ftfy dill
  # By default, start container
  CMD ["/start.sh"]

# Stage 2: Download models
FROM base as downloader

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

  WORKDIR /comfyui
  
  # Create necessary directories for models
  RUN mkdir -p models/loras models/checkpoints models/vae models/text_encoders models/diffusion_models models/clip models/clip_vision models/upscale_models
  
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
  
  
  # --------------------------------------------------------
  # Stage 3: Final image
  # --------------------------------------------------------
  FROM base as final
  
  ARG MODEL_TYPE
  
  # Copy models from stage 2 to the final image
  COPY --from=downloader /comfyui/models /comfyui/models

  # ------------ correctif SSL pour Let’s Encrypt R11 ----------
  RUN pip install --no-cache-dir --upgrade certifi urllib3 botocore boto3 awscli
  # ------------------------------------------------------------
  
  # Final command
  CMD ["/start.sh"]
  