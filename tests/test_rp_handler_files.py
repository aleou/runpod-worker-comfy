import unittest
from unittest.mock import patch
import sys
import os
import base64
import tempfile

# Import rp_handler under the same module name the patches below target
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src")))
import rp_handler


class TestInputFiles(unittest.TestCase):
    def test_sanitize_keeps_basename_only(self):
        self.assertEqual(rp_handler.sanitize_input_filename("voice.wav"), "voice.wav")
        self.assertEqual(rp_handler.sanitize_input_filename("sub/dir/first.PNG"), "first.PNG")
        self.assertEqual(rp_handler.sanitize_input_filename("/etc/cron.d/clip.mp4"), "clip.mp4")
        self.assertEqual(rp_handler.sanitize_input_filename("C:\\temp\\ref0.png"), "ref0.png")

    def test_sanitize_rejects_traversal_and_unknown_extensions(self):
        for name in ["../../rp_handler.py", "..\\x.png", "a/../b.png", "run.sh", "model.safetensors", "noext", "", None]:
            with self.assertRaises(ValueError):
                rp_handler.sanitize_input_filename(name)

    def test_validate_input_accepts_url_or_data(self):
        job_input = {
            "workflow": {},
            "files": [
                {"name": "voice.wav", "url": "https://example.com/voice.wav"},
                {"name": "ref0.png", "data": "aGVsbG8="},
            ],
        }
        validated, error = rp_handler.validate_input(job_input)
        self.assertIsNone(error)
        self.assertEqual(len(validated["files"]), 2)

    def test_validate_input_rejects_bad_files(self):
        for files in [
            [{"name": "voice.wav"}],
            [{"name": "../voice.wav", "url": "https://example.com/voice.wav"}],
            [{"name": "voice.exe", "data": "aGVsbG8="}],
        ]:
            _, error = rp_handler.validate_input({"workflow": {}, "files": files})
            self.assertIsNotNone(error)

    def test_base64_file_is_written_then_cleaned_up(self):
        with tempfile.TemporaryDirectory() as input_dir:
            with patch.dict(os.environ, {"COMFY_INPUT_PATH": input_dir}):
                payload = base64.b64encode(b"hello").decode("utf-8")
                result = rp_handler.download_files_from_urls(
                    [
                        {"name": "ref0.png", "data": payload},
                        {"name": "voice.wav", "data": "data:audio/wav;base64," + payload},
                    ]
                )

            self.assertEqual(result["status"], "success")
            self.assertEqual(len(result["paths"]), 2)
            for path in result["paths"]:
                self.assertEqual(os.path.dirname(path), input_dir)
                with open(path, "rb") as f:
                    self.assertEqual(f.read(), b"hello")

            rp_handler.cleanup_job_files(result["paths"] + [os.path.join(input_dir, "missing.png")])
            self.assertEqual(os.listdir(input_dir), [])

    @patch("rp_handler.check_server")
    def test_handler_requires_s3_before_generating(self, mock_check_server):
        with patch.object(rp_handler, "REQUIRE_S3", True), patch.dict(os.environ, {}, clear=False):
            os.environ.pop("BUCKET_ENDPOINT_URL", None)
            result = rp_handler.handler({"id": "123", "input": {"workflow": {}}})

        self.assertIn("BUCKET_ENDPOINT_URL", result["error"])
        mock_check_server.assert_not_called()

    def test_save_video_output_is_found_and_removed_after_job(self):
        with tempfile.TemporaryDirectory() as output_dir:
            os.makedirs(os.path.join(output_dir, "video"))
            video_path = os.path.join(output_dir, "video", "MiniMax_H3_00001_.mp4")
            with open(video_path, "wb") as f:
                f.write(b"mp4")

            # What ComfyUI's SaveVideo reports in the history
            outputs = {
                "20": {
                    "images": [{"filename": "MiniMax_H3_00001_.mp4", "subfolder": "video", "type": "output"}],
                    "animated": [True],
                }
            }
            cleanup_paths = []
            with patch.dict(os.environ, {"COMFY_OUTPUT_PATH": output_dir}):
                os.environ.pop("BUCKET_ENDPOINT_URL", None)
                result = rp_handler.process_output_images(outputs, "123", cleanup_paths)

            self.assertEqual(result["status"], "success")
            self.assertEqual(result["files"][0]["filename"], "MiniMax_H3_00001_.mp4")
            self.assertEqual(cleanup_paths, [video_path])

            rp_handler.cleanup_job_files(cleanup_paths)
            self.assertFalse(os.path.exists(video_path))


if __name__ == "__main__":
    unittest.main()
