# 🪣 Configuration S3 pour Upload des Vidéos

## 🎯 Configuration Simple

Le worker supporte maintenant une variable `BUCKET_NAME` séparée pour plus de flexibilité !

## ✅ Configuration Correcte

Dans **RunPod Serverless → Settings → Environment Variables**, ajoutez :

### Option 1 : Variables séparées (RECOMMANDÉ)

```bash
BUCKET_ENDPOINT_URL=https://s3.eu-west-3.amazonaws.com
BUCKET_NAME=runpodvid
BUCKET_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
BUCKET_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**Avantages :**
- ✅ Réutilisable pour plusieurs buckets
- ✅ Configuration globale RunPod compatible
- ✅ Plus facile à gérer

### Option 2 : URL complète (legacy)

```bash
BUCKET_ENDPOINT_URL=https://votre-bucket-name.s3.eu-west-1.amazonaws.com
BUCKET_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
BUCKET_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**Format de l'URL :**
```
https://<BUCKET_NAME>.s3.<REGION>.amazonaws.com
```

### Option 2 : S3-Compatible (MinIO, Wasabi, etc.)

```bash
BUCKET_ENDPOINT_URL=https://s3.<region>.<provider>.com
BUCKET_NAME=mon-bucket
BUCKET_ACCESS_KEY_ID=votre-access-key
BUCKET_SECRET_ACCESS_KEY=votre-secret-key
```

### Option 3 : RunPod Network Storage (Recommandé)

RunPod fournit automatiquement un bucket S3 si vous activez **Network Storage** :

1. Allez dans **RunPod Serverless → Your Endpoint → Settings**
2. Activez **Network Volume**
3. RunPod configurera automatiquement les variables `BUCKET_*`

## 🔍 Vérification

Après configuration, vos vidéos seront uploadées et vous recevrez :

```json
{
  "status": "success",
  "message": "https://votre-bucket.s3.region.amazonaws.com/job-id/video.mp4",
  "files": [
    {
      "filename": "AnimateDiff_00001-audio.mp4",
      "url": "https://votre-bucket.s3.region.amazonaws.com/job-id/AnimateDiff_00001-audio.mp4",
      "type": "video/h264-mp4",
      "format": "video/h264-mp4",
      "status": "success"
    }
  ]
}
```

## ❌ Configuration Incorrecte (ERREUR)

```bash
# ❌ INCORRECT - Sans le nom du bucket
BUCKET_ENDPOINT_URL=https://s3.eu-west-1.amazonaws.com

# ✅ CORRECT - Avec le nom du bucket
BUCKET_ENDPOINT_URL=https://mon-bucket.s3.eu-west-1.amazonaws.com
```

## 🔐 Permissions IAM Requises

Votre utilisateur IAM doit avoir ces permissions sur le bucket :

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::votre-bucket-name/*"
    }
  ]
}
```

## 📦 Alternative : Retour en Base64

Si vous ne voulez **PAS** utiliser S3, **ne définissez pas** `BUCKET_ENDPOINT_URL`.

Les vidéos seront retournées en **base64** :

```json
{
  "status": "success",
  "message": "data:video/mp4;base64,AAAAHGZ0eXBpc29tAAAC...",
  "files": [...]
}
```

⚠️ **Attention** : Les vidéos en base64 peuvent être **très volumineuses** (plusieurs Mo → plusieurs dizaines de Mo encodés).
