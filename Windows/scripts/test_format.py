import unittest
from format import spacing


class SpacingTests(unittest.TestCase):
    def test_method_and_control_spacing(self):
        source = "public virtual void Render()\n{\n    var value = 1;\n    if (value > 0)\n    {\n        Draw();\n    }\n}\n"
        result = spacing(source)
        self.assertIn("Render()\n{\n\n", result)
        self.assertIn("var value = 1;\n\n    if", result)
        self.assertIn("if (value > 0)\n    {\n        Draw", result)

    def test_types_do_not_get_method_spacing(self):
        source = "internal sealed class Board(View view)\n{\n    private int count;\n}\n"
        self.assertEqual(source, spacing(source))

    def test_result_is_idempotent(self):
        source = "private void Update()\n{\n    var count = 3;\n    while (count-- > 0)\n    {\n        Draw();\n    }\n}\n"
        self.assertEqual(spacing(source), spacing(spacing(source)))


if __name__ == "__main__":
    unittest.main()
