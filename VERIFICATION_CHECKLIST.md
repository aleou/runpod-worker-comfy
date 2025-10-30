# ✅ Checklist de vérification - Nouvelle image Watermark

## 🎯 Image Docker

- [x] Target `watermark` ajouté dans `docker-bake.hcl`
- [x] Target inclus dans le groupe `default`
- [x] Bloc de téléchargement des modèles dans `Dockerfile`
- [x] 2 modèles configurés:
  - `models/diffusers/pcm_sd15_smallcfg_2step_converted.safetensors`
  - `models/checkpoints/realisticVisionV51_v51VAE.safetensors`
- [x] Snapshot `snapshot-watermark.json` présent

## 📦 Téléchargement de fichiers (files via URL)

### Vérifications du code

- [x] Fonction `download_files_from_urls()` présente dans `rp_handler.py`
- [x] Validation du paramètre `files` dans `validate_input()`
- [x] Appel de `download_files_from_urls()` dans `handler()`
- [x] Gestion d'erreurs avec timeout de 60s
- [x] Support du streaming pour fichiers volumineux (`stream=True`)
- [x] Création automatique du dossier `/comfyui/input/`

### Format attendu

```json
{
  "input": {
    "workflow": { ... },
    "files": [
      {
        "name": "ma_video.mp4",
        "url": "https://bucket.s3.amazonaws.com/video.mp4"
      }
    ]
  }
}
```

### Validation

- [x] Chaque fichier doit avoir `name` et `url`
- [x] `files` est optionnel (peut être null/omis)
- [x] Compatible avec `images` (base64) simultanément
- [x] Messages de log clairs pour debugging

## 🧪 Tests à effectuer

### Test 1: Build de l'image

```bash
# Build uniquement watermark
docker buildx bake watermark

# Vérifier que l'image est créée
docker images | grep watermark
```

**Résultat attendu**: Image `aleou/runpod-worker-comfy:5.0-watermark` créée

### Test 2: Téléchargement fichier depuis URL

```bash
# Tester avec example_watermark_workflow.json
# Remplacer l'URL par une vraie URL accessible
```

**Résultat attendu**:
- Log: "downloading file(s) from URL(s)"
- Log: "downloading input_video.mp4 from https://..."
- Log: "saved input_video.mp4 to /comfyui/input/input_video.mp4"
- Log: "file(s) download complete"
- Fichier présent dans `/comfyui/input/`

### Test 3: Workflow complet

1. Vidéo téléchargée depuis URL
2. Vidéo chargée dans ComfyUI
3. Watermark appliqué
4. Vidéo exportée

**Résultat attendu**: Vidéo watermarkée en sortie

### Test 4: Gestion d'erreurs

- URL invalide → Message d'erreur clair
- Timeout → Message "Connection timeout"
- Fichier manquant → Message "Error downloading"

## 📝 Documentation

- [x] `WATERMARK_GUIDE.md` créé
- [x] `example_watermark_workflow.json` créé
- [x] `FILE_DOWNLOAD_GUIDE.md` déjà créé
- [x] `CURL_EXAMPLES.md` déjà créé

## 🔍 Vérifications finales

### Dockerfile

```dockerfile
# Bloc ajouté pour watermark
RUN if [ "$MODEL_TYPE" = "watermark" ]; then \
  aria2c -x16 -s16 -d models/diffusers -o pcm_sd15_smallcfg_2step_converted.safetensors \
    https://huggingface.co/wangfuyun/PCM_Weights/resolve/main/sd15/pcm_sd15_smallcfg_2step_converted.safetensors & \
  aria2c -x16 -s16 -d models/checkpoints -o realisticVisionV51_v51VAE.safetensors \
    https://huggingface.co/lllyasviel/fav_models/resolve/main/fav/realisticVisionV51_v51VAE.safetensors & \
  wait; \
fi
```

### docker-bake.hcl

```hcl
target "watermark" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "watermark"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}-watermark"]
  inherits = ["base"]
}
```

### rp_handler.py - Fonction clé

```python
def download_files_from_urls(files):
    if not files:
        return {"status": "success", "message": "No files to download", "details": []}
    
    COMFY_INPUT_PATH = os.environ.get("COMFY_INPUT_PATH", "/comfyui/input")
    os.makedirs(COMFY_INPUT_PATH, exist_ok=True)
    
    for file in files:
        name = file["name"]
        url = file["url"]
        response = requests.get(url, timeout=60, stream=True)
        # ... sauvegarde dans COMFY_INPUT_PATH
```

## ✅ Prêt pour le build !

Toutes les vérifications sont complètes. Vous pouvez lancer le build :

```bash
# Build de l'image watermark
docker buildx bake watermark

# Ou build de toutes les images
docker buildx bake

# Push vers Docker Hub
docker push aleou/runpod-worker-comfy:5.0-watermark
```

## 🎯 Utilisation

Une fois l'image déployée sur RunPod :

```bash
curl -X POST https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d @example_watermark_workflow.json
```

## 📊 Points clés

1. ✅ La vidéo sera téléchargée automatiquement depuis l'URL
2. ✅ Sauvegardée dans `/comfyui/input/input_video.mp4`
3. ✅ Accessible dans le workflow ComfyUI
4. ✅ Pas besoin d'encoder en base64
5. ✅ Fonctionne avec S3, CloudFront, URLs publiques
