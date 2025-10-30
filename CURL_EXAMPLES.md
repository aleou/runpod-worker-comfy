# Exemples de requêtes cURL pour RunPod

## 🎬 Exemple 1 : Upscale vidéo depuis S3

```bash
curl -X POST https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
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
        "8": {
          "inputs": {
            "frame_rate": ["9", 0],
            "loop_count": 0,
            "filename_prefix": "upscaled",
            "format": "video/h264-mp4",
            "pix_fmt": "yuv420p",
            "crf": 19,
            "save_metadata": true,
            "trim_to_audio": false,
            "pingpong": false,
            "save_output": true,
            "images": ["12", 0],
            "audio": ["7", 2]
          },
          "class_type": "VHS_VideoCombine"
        },
        "9": {
          "inputs": {
            "video_info": ["7", 3]
          },
          "class_type": "VHS_VideoInfo"
        },
        "12": {
          "inputs": {
            "aggressive_cleanup": "disable",
            "report_memory": "enable",
            "images": ["13", 0]
          },
          "class_type": "Free_Video_Memory"
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
  }'
```

## 🖼️ Exemple 2 : Image depuis CloudFront

```bash
curl -X POST https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "input": {
      "workflow": {
        "1": {
          "inputs": {
            "image": "input.jpg",
            "upload": "image"
          },
          "class_type": "LoadImage"
        },
        "2": {
          "inputs": {
            "upscale_model_name": "4x_foolhardy_Remacri.pth"
          },
          "class_type": "UpscaleModelLoader"
        },
        "3": {
          "inputs": {
            "upscale_model": ["2", 0],
            "image": ["1", 0]
          },
          "class_type": "ImageUpscaleWithModel"
        },
        "4": {
          "inputs": {
            "filename_prefix": "upscaled",
            "images": ["3", 0]
          },
          "class_type": "SaveImage"
        }
      },
      "files": [
        {
          "name": "input.jpg",
          "url": "https://d1234567890.cloudfront.net/images/photo.jpg"
        }
      ]
    }
  }'
```

## 🔄 Exemple 3 : Plusieurs fichiers (vidéo + logo)

```bash
curl -X POST https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "input": {
      "workflow": { ... },
      "files": [
        {
          "name": "video.mp4",
          "url": "https://example.com/video.mp4"
        },
        {
          "name": "watermark.png",
          "url": "https://example.com/logo.png"
        }
      ]
    }
  }'
```

## 📝 Exemple 4 : Depuis un fichier JSON

```bash
# Créez un fichier request.json avec votre requête
curl -X POST https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d @request.json
```

## 🐍 Exemple Python

```python
import requests
import json

RUNPOD_ENDPOINT_ID = "YOUR_ENDPOINT_ID"
RUNPOD_API_KEY = "YOUR_API_KEY"

payload = {
    "input": {
        "workflow": {
            # Votre workflow ComfyUI ici
        },
        "files": [
            {
                "name": "ma_video.mp4",
                "url": "https://mon-bucket.s3.amazonaws.com/videos/input.mp4"
            }
        ]
    }
}

response = requests.post(
    f"https://api.runpod.ai/v2/{RUNPOD_ENDPOINT_ID}/runsync",
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {RUNPOD_API_KEY}"
    },
    json=payload
)

result = response.json()
print(json.dumps(result, indent=2))
```

## 🟢 Exemple Node.js

```javascript
const axios = require('axios');

const RUNPOD_ENDPOINT_ID = 'YOUR_ENDPOINT_ID';
const RUNPOD_API_KEY = 'YOUR_API_KEY';

const payload = {
  input: {
    workflow: {
      // Votre workflow ComfyUI ici
    },
    files: [
      {
        name: 'ma_video.mp4',
        url: 'https://mon-bucket.s3.amazonaws.com/videos/input.mp4'
      }
    ]
  }
};

axios.post(
  `https://api.runpod.ai/v2/${RUNPOD_ENDPOINT_ID}/runsync`,
  payload,
  {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${RUNPOD_API_KEY}`
    }
  }
)
.then(response => {
  console.log(JSON.stringify(response.data, null, 2));
})
.catch(error => {
  console.error('Error:', error.response?.data || error.message);
});
```

## ⚙️ Variables d'environnement

Avant d'exécuter les exemples, configurez :

```bash
export RUNPOD_ENDPOINT_ID="votre-endpoint-id"
export RUNPOD_API_KEY="votre-api-key"
```

Puis utilisez dans cURL :

```bash
curl -X POST https://api.runpod.ai/v2/$RUNPOD_ENDPOINT_ID/runsync \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -d @request.json
```

## 🔍 Vérifier le statut

Pour une requête asynchrone (`/run` au lieu de `/runsync`) :

```bash
# Lancer la requête
RESPONSE=$(curl -X POST https://api.runpod.ai/v2/$RUNPOD_ENDPOINT_ID/run \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -d @request.json)

# Extraire l'ID
JOB_ID=$(echo $RESPONSE | jq -r '.id')

# Vérifier le statut
curl https://api.runpod.ai/v2/$RUNPOD_ENDPOINT_ID/status/$JOB_ID \
  -H "Authorization: Bearer $RUNPOD_API_KEY"
```

## 📊 Réponse attendue

```json
{
  "delayTime": 2343,
  "executionTime": 45123,
  "id": "job-id-123",
  "output": {
    "status": "success",
    "message": "https://bucket.s3.amazonaws.com/output/upscaled_video.mp4"
  },
  "status": "COMPLETED"
}
```
