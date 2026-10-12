# Cible `minimax-h3`

Vidéo avec audio via MiniMax H3 sous ComfyUI, accélérée par la LoRA turbo 8 steps et Veda.
Image autoportée : les 9 modèles (64,5 Go) sont dans l'image, aucun network volume.

## Versions figées

| Composant | Version |
| --- | --- |
| Base | `runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04` |
| PyTorch | `torch 2.14.1+cu130`, `torchvision 0.29.1+cu130` (Triton 3.8 tiré par torch) |
| ComfyUI | `v0.39.2` |
| Veda | `veda-sparse-attention` 0.3.1, commit `8d7ac153ac215d636eaf1b5910b0536c3de9e6ed` |
| Modèles | URL Hugging Face figées par hash de commit, taille et SHA-256 vérifiés au build |

`torchaudio` n'est pas installé : ComfyUI 0.39.2 ne l'importe pas et il n'existe pas de roue cu130 pour torch 2.14.

## Build et push

Machine Linux avec Docker buildx et au moins 250 Go de disque libre.

```bash
# facultatif : évite le rate-limit Hugging Face (passé en secret BuildKit, pas en ARG)
export HUGGINGFACE_ACCESS_TOKEN=hf_xxx

RELEASE_VERSION=5.13 docker buildx bake minimax-h3 --push
```

Tag produit : `aleou/runpod-worker-comfy:minimax-h3-<RELEASE_VERSION>`.
L'image contient les poids MiniMax : le dépôt de destination doit être **privé**. Pour pousser ailleurs
que dans `aleou/runpod-worker-comfy`, surcharger `DOCKERHUB_REPO` et `DOCKERHUB_IMG`.

Les versions se surchargent par variable d'environnement : `TORCH_VERSION`, `TORCHVISION_VERSION`, `VEDA_COMMIT`.
Le build échoue si torch n'est pas en CUDA 13, si Triton ne s'importe pas, ou si un modèle n'a pas la bonne taille ou le bon hash.

La cible n'est pas dans le groupe `default`. Le code (`start.sh`, `rp_handler.py`, workflows) est copié en dernière
couche : modifier le handler ne retélécharge pas les modèles.

## Variables d'environnement

| Variable | Valeur | Rôle |
| --- | --- | --- |
| `BUCKET_ENDPOINT_URL`, `BUCKET_ACCESS_KEY_ID`, `BUCKET_SECRET_ACCESS_KEY`, `BUCKET_NAME` | à fournir | S3 **obligatoire** : sans `BUCKET_ENDPOINT_URL` le job est refusé avant génération |
| `SERVE_API_LOCALLY` | `true` sur le pod de test, absent en serverless | expose l'API du handler sur le port 8000 |
| `REQUIRE_S3` | `true` (dans l'image) | interdit le retour en base64 |
| `REFRESH_WORKER` | `false` (dans l'image) | garde les modèles chargés entre deux jobs |
| `COMFY_POLLING_MAX_RETRIES` | `7200` (dans l'image) | 30 min d'attente à 250 ms |
| `COMFY_API_AVAILABLE_MAX_RETRIES` | `3600` par défaut | 180 s d'attente du démarrage de ComfyUI |
| `CLEANUP_JOB_FILES` | `true` par défaut | supprime les fichiers d'entrée et de sortie en fin de job |
| `ALLOWED_INPUT_EXTENSIONS` | `png,jpg,jpeg,webp,wav,mp3,flac,m4a,mp4,mov,webm` | extensions acceptées dans `files[]` |

## GPU

- Premier test sur 80 Go (H100 ou A100), puis L40S 48 Go.
- Filtre **CUDA 13.0** obligatoire sur le pod et sur l'endpoint (driver ≥ 580).
- Container disk ≥ 100 Go. Ports HTTP du pod : 8188 (UI ComfyUI) et 8000 (API du handler).

Au démarrage, les logs affichent `torch 2.14.1+cu130 cuda 13.0 gpu <nom>`. C'est le premier endroit à regarder.

## Workflows

Six workflows au format API dans `workflows/minimax-h3/` (copiés dans `/workflows/` de l'image) :

| Fichier | Modèle + LoRA | Veda | Fichiers attendus dans `input/` |
| --- | --- | --- | --- |
| `h3_t2v.json` | FL2VA + `fl2v_turbo_8step` | T2VA | aucun |
| `h3_i2v.json` | FL2VA + `fl2v_turbo_8step` | T2VA | `first.png` |
| `h3_flf.json` | FL2VA + `fl2v_turbo_8step` | T2VA | `first.png`, `last.png` |
| `h3_ref_audio.json` | Ref2VA + `ref2v_turbo_8step` | R2VA | `ref0.png`, `voice.mp3` |
| `h3_ref_full.json` | Ref2VA + `ref2v_turbo_8step` | R2VA | `ref0.png`, `voice.mp3`, `guide_first.png`, `guide_last.png` |
| `h3_t2v_noveda.json` | FL2VA + `fl2v_turbo_8step` | aucun | aucun |

Ils ont été écrits à partir des templates Veda (T2VA et R2VA) et des schémas de nœuds de ComfyUI 0.39.2, pas exportés
depuis l'UI. **À valider sur le pod** avant de les donner à n8n : si l'un d'eux est refusé par `/prompt`, l'ouvrir dans
l'UI, corriger, refaire Export (API), puis relancer `python scripts/make_h3_test_inputs.py`.

Nœuds à modifier par n8n, repérables par leur titre (`_meta.title`) :

| Titre | Nœud | Champ |
| --- | --- | --- |
| `PROMPT` | `PrimitiveStringMultiline` | `value` |
| `WIDTH`, `HEIGHT`, `LENGTH` | `PrimitiveInt` | `value` |
| `SEED` | `RandomNoise` | `noise_seed` |
| `STEPS` | `BasicScheduler` | `steps` (8) |
| `FIRST_FRAME`, `LAST_FRAME`, `REF_IMAGE_0`, `GUIDE_FIRST`, `GUIDE_LAST` | `LoadImage` | `image` |
| `REF_AUDIO_0` | `LoadAudio` | `audio` |
| `GUIDE_FIRST_IDX`, `GUIDE_LAST_IDX` | `MiniMaxH3AddGuide` | `frame_idx` (0 et -1) |
| `VEDA` | `VedaSparseAttention` | `verbose`, `generated_sparsity`, `reference_sparsity` |

- `LENGTH` est en frames à 24 fps : `n = max(5, round(durée × 24))`, arrondi au supérieur pour que `n mod 17 = 5`
  (5 s → 124, 10 s → 243). Le nœud arrondit lui-même au supérieur.
- Résolutions dans la zone d'entraînement de Veda : 1344×768, 768×1344, 768×768, 1024×768.
- `frame_idx = -1` désigne la dernière frame (les valeurs négatives comptent depuis la fin).
- Références supplémentaires en Ref2VA : ajouter un `LoadImage` et le brancher sur `ref_images.ref_image_1` (puis `_2`)
  du nœud `MiniMaxH3ReferenceToVideo`. Dans le prompt, les références s'appellent `<Picture 1>`, `<Audio 1>`, etc.

## Contrat d'entrée et de sortie

```json
{
  "input": {
    "workflow": { "…": "workflow API" },
    "images": [ { "name": "first.png", "image": "<base64>" } ],
    "files":  [ { "name": "voice.wav", "url": "https://…/voice.wav" },
                { "name": "ref0.png",  "data": "<base64>" } ]
  }
}
```

Les noms doivent correspondre à ceux des nœuds `LoadImage`, `LoadAudio` et `LoadVideo`. Seul le nom de base est
gardé ; un nom contenant `..` ou une extension hors liste est refusé.

Sortie : `{ "status": "success", "files": [ { "url": "https://<bucket>/<job_id>/MiniMax_H3_00001_.mp4", … } ] }`.

## Tests

Sur le pod (`SERVE_API_LOCALLY=true`), les six fichiers sont à la racine de l'image :

```bash
for m in t2v i2v flf ref_audio ref_full t2v_noveda; do
  curl -s -X POST http://localhost:8000/runsync \
    -H "Content-Type: application/json" -d @/test_input_h3_$m.json; echo
done
```

Sur l'endpoint serverless, utiliser `/run` puis `/status/<id>` (un job vidéo dépasse l'attente de `/runsync`) :

```bash
curl -s -X POST https://api.runpod.ai/v2/<ENDPOINT_ID>/run \
  -H "Authorization: Bearer $RUNPOD_API_KEY" -H "Content-Type: application/json" \
  -d @test_input_h3_t2v.json
curl -s https://api.runpod.ai/v2/<ENDPOINT_ID>/status/<JOB_ID> -H "Authorization: Bearer $RUNPOD_API_KEY"
```

Pour vérifier que Veda tourne bien sur le noyau `triton-int8`, passer `verbose` à `true` sur le nœud `VEDA`
et lire les logs du worker.

Tests unitaires du handler : `python -m unittest tests.test_rp_handler_files`.
