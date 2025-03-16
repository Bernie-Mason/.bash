import unittest
from second_lowest import second_lowest

class TestSecondLowest(unittest.TestCase):
    def test_normal_case(self):
        self.assertEqual(second_lowest([4, 1, 7, 3, 2, 5, 1, 3]), 2)

    def test_with_duplicates(self):
        with self.assertRaises(ValueError):
            second_lowest([4, 4, 4, 4, 4, 4, 4, 4])

    def test_with_negative_numbers(self):
        self.assertEqual(second_lowest([4, -1, 7, 3, 2, -5, 1, 3]), -1)

    def test_with_two_elements(self):
        self.assertEqual(second_lowest([4, 1]), 4)

    def test_with_identical_elements(self):
        with self.assertRaises(ValueError):
            second_lowest([4, 4])

    def test_with_single_element(self):
        with self.assertRaises(ValueError):
            second_lowest([4])

    def test_with_empty_list(self):
        with self.assertRaises(ValueError):
            second_lowest([])

if __name__ == "__main__":
    unittest.main()