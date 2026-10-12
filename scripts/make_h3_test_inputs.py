#!/usr/bin/env python3
"""Rebuild test_input_h3_<mode>.json from workflows/minimax-h3/h3_<mode>.json.

The workflow files are the source of truth: run this after editing or
re-exporting one of them, so the curl-ready test inputs stay in sync.

    python scripts/make_h3_test_inputs.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOWS = os.path.join(ROOT, "workflows", "minimax-h3")

# Public test media, pinned to a commit of the Veda R2VA showcase
MEDIA = (
    "https://huggingface.co/Veda-Sparse/Minimax-H3-R2VA-Veda-Preview/resolve/"
    "1598b407905b7c0af85aa0c13acdfa6f01ff2982/media/showcase/"
)
CHARACTER = MEDIA + "03_anime_twilight_carnival/references/picture_1_character.png"
FAIRGROUND = MEDIA + "03_anime_twilight_carnival/references/picture_2_fairground.png"
TRAIN = MEDIA + "02_anime_train_coastal_window/references/picture_1.png"
VOICE = MEDIA + "01_pink_lamb/references/audio_2_voice.mp3"

# The names must match the LoadImage / LoadAudio nodes of each workflow
FILES = {
    "t2v": [],
    "t2v_noveda": [],
    "i2v": [("first.png", CHARACTER)],
    "flf": [("first.png", CHARACTER), ("last.png", FAIRGROUND)],
    "ref_audio": [("ref0.png", CHARACTER), ("voice.mp3", VOICE)],
    "ref_full": [
        ("ref0.png", CHARACTER),
        ("voice.mp3", VOICE),
        ("guide_first.png", FAIRGROUND),
        ("guide_last.png", TRAIN),
    ],
}

LOADERS = {"LoadImage": "image", "LoadAudio": "audio", "LoadVideo": "file"}


def main():
    for mode, files in FILES.items():
        with open(os.path.join(WORKFLOWS, f"h3_{mode}.json"), encoding="utf-8") as f:
            workflow = json.load(f)

        expected = sorted(
            node["inputs"][LOADERS[node["class_type"]]]
            for node in workflow.values()
            if node["class_type"] in LOADERS
        )
        provided = sorted(name for name, _ in files)
        if expected != provided:
            raise SystemExit(f"h3_{mode}: workflow loads {expected}, test input provides {provided}")

        job_input = {"workflow": workflow}
        if files:
            job_input["files"] = [{"name": name, "url": url} for name, url in files]

        path = os.path.join(ROOT, f"test_input_h3_{mode}.json")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump({"input": job_input}, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"wrote {os.path.relpath(path, ROOT)}")


if __name__ == "__main__":
    main()
