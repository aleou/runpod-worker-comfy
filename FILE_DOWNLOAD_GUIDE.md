# Guide d'utilisation - Téléchargement de fichiers depuis des URLs

## 🎯 Nouvelle fonctionnalité : Support des fichiers via URL

Le handler RunPod supporte maintenant le téléchargement automatique de fichiers (images, vidéos) depuis des URLs directement dans le dossier `input` de ComfyUI.

## 📝 Format de la requête

### Structure JSON

```json
{
  "input": {
    "workflow": { ... },
    "files": [
      {
        "name": "nom_du_fichier.ext",
        "url": "https://example.com/path/to/file.ext"
      }
    ]
  }
}
```

### Champs

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `files` | Array | Non | Liste des fichiers à télécharger |
| `files[].name` | String | Oui | Nom du fichier tel qu'il sera sauvegardé dans ComfyUI |
| `files[].url` | String | Oui | URL publique du fichier à télécharger |

## 🎬 Exemples d'utilisation

### Exemple 1 : Upscale d'une vidéo depuis une URL

```json
{
  "input": {
    "workflow": {
      "7": {
        "inputs": {
          "video": "ma_video.mp4",
          "force_rate": 0,
          "custom_width": 0,
          "custom_height": 0,
          "frame_load_cap": 0,
          "skip_first_frames": 0,
          "select_every_nth": 1,
          "format": "AnimateDiff"
        },
        "class_type": "VHS_LoadVideo"
      },
      "13": {
        "inputs": {
          "model_name": "realesr-general-x4v3.pth",
          "upscale_method": "nearest-exact",
          "factor": 2,
          "device_strategy": "keep_loaded",
          "images": ["7", 0]
        },
        "class_type": "Video_Upscale_With_Model"
      }
    },
    "files": [
      {
        "name": "ma_video.mp4",
        "url": "https://mon-bucket.s3.amazonaws.com/videos/input.mp4"
      }
    ]
  }
}
```

### Exemple 2 : Plusieurs fichiers (vidéo + image)

```json
{
  "input": {
    "workflow": { ... },
    "files": [
      {
        "name": "video_source.mp4",
        "url": "https://example.com/video.mp4"
      },
      {
        "name": "watermark.png",
        "url": "https://example.com/logo.png"
      }
    ]
  }
}
```

### Exemple 3 : Image depuis CloudFront

```json
{
  "input": {
    "workflow": { ... },
    "files": [
      {
        "name": "input_image.jpg",
        "url": "https://d1234567890.cloudfront.net/images/photo.jpg"
      }
    ]
  }
}
```

## 🔧 Fonctionnement

1. **Validation** : Le handler vérifie que chaque fichier a un `name` et une `url`
2. **Téléchargement** : Les fichiers sont téléchargés depuis les URLs
3. **Sauvegarde** : Les fichiers sont sauvegardés dans `/comfyui/input/`
4. **Utilisation** : Vous pouvez référencer les fichiers dans votre workflow par leur `name`

## ⚠️ Points importants

- ✅ **URLs publiques uniquement** : Les URLs doivent être accessibles sans authentification
- ✅ **Timeout** : 60 secondes par fichier
- ✅ **Nom du fichier** : Le `name` doit correspondre exactement au nom utilisé dans votre workflow ComfyUI
- ✅ **Extensions supportées** : `.mp4`, `.mov`, `.avi`, `.png`, `.jpg`, `.jpeg`, `.webp`, etc.
- ✅ **Taille** : Pas de limite de taille (mais pensez au timeout de 60s)

## 🚀 Workflow ComfyUI

Dans votre workflow ComfyUI, référencez simplement le fichier par son nom :

```json
{
  "7": {
    "inputs": {
      "video": "ma_video.mp4",  // ← Nom du fichier téléchargé
      ...
    },
    "class_type": "VHS_LoadVideo"
  }
}
```

## 🔄 Combinaison avec images base64

Vous pouvez utiliser à la fois `files` (URL) et `images` (base64) dans la même requête :

```json
{
  "input": {
    "workflow": { ... },
    "files": [
      {
        "name": "video.mp4",
        "url": "https://example.com/video.mp4"
      }
    ],
    "images": [
      {
        "name": "overlay.png",
        "image": "iVBORw0KGgo..."
      }
    ]
  }
}
```

## 📊 Gestion des erreurs

En cas d'erreur, vous recevrez un message détaillé :

```json
{
  "status": "error",
  "message": "Some files failed to download",
  "details": [
    "Error downloading ma_video.mp4 from https://...: Connection timeout"
  ]
}
```

## 🎯 Cas d'usage

- **Upscaling vidéo** : Télécharger une vidéo depuis S3/CloudFront et l'upscaler
- **Traitement par lot** : Traiter plusieurs images/vidéos hébergées en ligne
- **Intégration pipeline** : Connecter à d'autres services cloud
- **Webhooks** : Recevoir des URLs de fichiers via webhook et les traiter automatiquement

## 📍 Emplacement des fichiers

Les fichiers téléchargés sont sauvegardés dans :
- Chemin par défaut : `/comfyui/input/`
- Variable d'environnement : `COMFY_INPUT_PATH` (optionnel)

## 🧪 Test en local

Pour tester localement, utilisez le fichier `test_input_video_upscale.json` fourni :

```bash
python src/rp_handler.py < test_input_video_upscale.json
```
