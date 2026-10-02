"""Run with: python3 -m unittest discover -s tools/android -p 'test_*.py'."""

import unittest

from verify_16kb_page_size import ValidationError, parse_program_headers


class ProgramHeadersTest(unittest.TestCase):
    # From Flutter 3.49.0-0.2.pre's published ARM64 release engine.
    FLUTTER = """
LOAD 0x000000 0x000000 0x000000 0xa68b70 0xa68b70 R E 0x10000
LOAD 0xa68b70 0xa78b70 0xa78b70 0x5c170 0x5c490 RW 0x10000
LOAD 0xac4ce0 0xae4ce0 0xae4ce0 0x16a0 0x10b78 RW 0x10000
GNU_RELRO 0xa68b70 0xa78b70 0xa78b70 0x5c170 0x5c490 R 0x1
"""

    def test_whole_load_relro_accepts_reported_flutter_engine(self):
        parse_program_headers(self.FLUTTER, "libflutter.so")

    def test_writable_tail_still_fails_even_within_same_16kb_page(self):
        headers = self.FLUTTER.replace("0x5c490 RW", "0x5c491 RW")
        with self.assertRaisesRegex(ValidationError, "GNU_RELRO end"):
            parse_program_headers(headers, "libflutter.so")

    def test_writable_prefix_does_not_get_whole_load_exemption(self):
        headers = self.FLUTTER.replace(
            "GNU_RELRO 0xa68b70 0xa78b70 0xa78b70 0x5c170 0x5c490",
            "GNU_RELRO 0xa68b80 0xa78b80 0xa78b80 0x5c160 0x5c480",
        )
        with self.assertRaisesRegex(ValidationError, "GNU_RELRO end"):
            parse_program_headers(headers, "libflutter.so")

    def test_4kb_load_still_fails(self):
        with self.assertRaisesRegex(ValidationError, "LOAD segments aligned below"):
            parse_program_headers(self.FLUTTER.replace("0x10000", "0x1000"), "bad.so")

    def test_aligned_relro_with_writable_tail_passes(self):
        parse_program_headers("""
LOAD 0x0000 0x4000 0x4000 0x5000 0x5000 RW 0x4000
GNU_RELRO 0x0000 0x4000 0x4000 0x4000 0x4000 R 0x1
""", "aligned.so")

    def test_no_relro_passes_and_no_load_fails(self):
        parse_program_headers("LOAD 0x0 0x0 0x0 0x1000 0x1000 R E 0x4000", "libapp.so")
        with self.assertRaisesRegex(ValidationError, "No ELF LOAD"):
            parse_program_headers("", "empty.so")


if __name__ == "__main__":
    unittest.main()
