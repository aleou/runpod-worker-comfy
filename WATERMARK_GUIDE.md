# Guide Watermark - Ajout de filigrane aux vidéos

## 🎯 Vue d'ensemble

Cette image Docker `watermark` permet d'ajouter des filigranes/watermarks aux vidéos en utilisant les modèles:
- **PCM SD1.5** (2-step): Pour la génération rapide
- **Realistic Vision V5.1**: Pour des résultats réalistes

## 📦 Modèles inclus

| Modèle | Emplacement | Source |
|--------|-------------|--------|
| PCM SD1.5 2-step | `models/diffusers/pcm_sd15_smallcfg_2step_converted.safetensors` | [HuggingFace](https://huggingface.co/wangfuyun/PCM_Weights) |
| Realistic Vision V5.1 | `models/checkpoints/realisticVisionV51_v51VAE.safetensors` | [HuggingFace](https://huggingface.co/lllyasviel/fav_models) |

## 🚀 Build de l'image

```bash
# Build de l'image watermark
docker buildx bake watermark

# Ou pour build toutes les images
docker buildx bake
```

## 📝 Utilisation avec RunPod

### Format de requête

```json
{
  "input": {
    "workflow": { /* votre workflow ComfyUI */ },
    "files": [
      {
        "name": "input_video.mp4",
        "url": "https://your-bucket.s3.amazonaws.com/videos/your-video.mp4"
      }
    ]
  }
}
```

### Exemple complet

```json
{
  "input": {
    "workflow": {
      "1": {
        "inputs": {
          "video": "input_video.mp4",
          "force_rate": 0,
          "format": "AnimateDiff"
        },
        "class_type": "VHS_LoadVideo"
      },
      "2": {
        "inputs": {
          "ckpt_name": "realisticVisionV51_v51VAE.safetensors"
        },
        "class_type": "CheckpointLoaderSimple"
      },
      "3": {
        "inputs": {
          "text": "watermark, logo, branding",
          "clip": ["2", 1]
        },
        "class_type": "CLIPTextEncode"
      },
      "6": {
        "inputs": {
          "seed": 42,
          "steps": 2,
          "cfg": 1.0,
          "model": ["2", 0],
          "positive": ["3", 0]
        },
        "class_type": "KSampler"
      },
      "8": {
        "inputs": {
          "filename_prefix": "watermarked",
          "format": "video/h264-mp4",
          "images": ["7", 0]
        },
        "class_type": "VHS_VideoCombine"
      }
    },
    "files": [
      {
        "name": "input_video.mp4",
        "url": "https://mon-bucket.s3.amazonaws.com/videos/input.mp4"
      }
    ]
  }
}
```

## 🎬 Workflow

1. **Téléchargement**: La vidéo est téléchargée depuis l'URL vers `/comfyui/input/`
2. **Chargement**: ComfyUI charge la vidéo
3. **Traitement**: Application du watermark via le workflow
4. **Export**: Vidéo watermarkée exportée

## ⚙️ Configuration

### Variables d'environnement RunPod

```bash
COMFY_INPUT_PATH=/comfyui/input  # Chemin des fichiers téléchargés
BUCKET_ENDPOINT_URL=https://...  # Pour upload S3 (optionnel)
BUCKET_ACCESS_KEY_ID=...         # Clés S3 (optionnel)
BUCKET_SECRET_ACCESS_KEY=...     # Clés S3 (optionnel)
```

## 🔧 Paramètres du workflow

### Paramètres recommandés

- **Steps**: 2 (PCM est optimisé pour 2 steps)
- **CFG**: 1.0 (configuration légère)
- **Denoise**: 0.3-0.7 (selon l'intensité souhaitée)
- **Format vidéo**: `video/h264-mp4`
- **CRF**: 19 (qualité élevée)

## 📊 Cas d'usage

1. **Ajout de logo**: Ajouter un logo d'entreprise
2. **Protection copyright**: Filigrane de protection
3. **Branding**: Personnalisation de marque
4. **Traitement batch**: Multiple vidéos via URLs

## 🎯 Avantages

- ✅ **Rapide**: 2 steps seulement avec PCM
- ✅ **Qualité**: Realistic Vision V5.1 pour des résultats réalistes
- ✅ **Flexible**: Téléchargement depuis S3/CloudFront
- ✅ **Automatisé**: Pipeline complet vidéo → watermark → upload

## 📍 Tag Docker

```
aleou/runpod-worker-comfy:5.0-watermark
```

## 🔗 Ressources

- [Documentation RunPod](https://docs.runpod.io/)
- [FILE_DOWNLOAD_GUIDE.md](FILE_DOWNLOAD_GUIDE.md) - Guide téléchargement fichiers
- [CURL_EXAMPLES.md](CURL_EXAMPLES.md) - Exemples de requêtes
- [example_watermark_workflow.json](example_watermark_workflow.json) - Exemple complet

## ⚠️ Notes importantes

- URLs doivent être **publiques** ou utiliser des URLs pré-signées S3
- Timeout de téléchargement: **60 secondes** par fichier
- Le nom du fichier dans `files` doit correspondre au nom dans le workflow
- Formats vidéo supportés: MP4, MOV, AVI, WebM
