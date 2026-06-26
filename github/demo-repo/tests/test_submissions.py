import json
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from scripts.validate_submissions import validate_all
from scripts.render_wall import render_page
import scripts.validate_submissions as validator


class SubmissionValidationTests(unittest.TestCase):
    def write_submission(self, root: Path, name: str, payload):
        submission_dir = root / "submissions"
        submission_dir.mkdir(parents=True, exist_ok=True)
        path = submission_dir / name
        path.write_text(json.dumps(payload), encoding="utf-8")
        return path

    def test_accepts_single_valid_submission(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_submission(
                root,
                "alice.json",
                {"handle": "alice", "message": "pipeline owned"},
            )

            self.assertEqual(validate_all(root), [])

    def test_rejects_filename_that_does_not_match_handle(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_submission(
                root,
                "alice.json",
                {"handle": "bob", "message": "pipeline owned"},
            )

            errors = validate_all(root)
            self.assertTrue(any("filename" in error for error in errors))

    def test_rejects_html_and_extra_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_submission(
                root,
                "alice.json",
                {
                    "handle": "alice",
                    "message": "<script>alert(1)</script>",
                    "extra": "nope",
                },
            )

            errors = validate_all(root)
            self.assertTrue(any("message" in error for error in errors))
            self.assertTrue(any("unexpected field" in error for error in errors))

    def test_rejects_duplicate_handles_ignoring_case(self):
        paths = [
            Path("submissions/alice.json"),
            Path("submissions/ALICE.json"),
        ]
        payloads = [
            ({"handle": "alice", "message": "first"}, None),
            ({"handle": "ALICE", "message": "second"}, None),
        ]

        with (
            patch.object(validator.Path, "exists", return_value=True),
            patch.object(validator.Path, "glob", return_value=paths),
            patch.object(validator, "load_json", side_effect=payloads),
        ):
            errors = validator.validate_all(Path("repo"))

        self.assertTrue(any("duplicate handle" in error for error in errors))
    
    def test_renderer_escapes_text_and_uses_x90sky_terminal_chrome(self):
        html = render_page([{"handle": "alice", "message": "owned & visible"}])

        self.assertIn("x90sky@rtv-lab", html)
        self.assertIn('class="scanlines"', html)
        self.assertIn("@alice", html)
        self.assertIn("owned &amp; visible", html)


if __name__ == "__main__":
    unittest.main()
