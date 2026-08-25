import requests
import unittest

BASE_URL = "http://localhost:8000"

class TestSearch(unittest.TestCase):
    def test_search_basic(self):
        res = requests.get(f"{BASE_URL}/search?q=Video")
        self.assertEqual(res.status_code, 200)
        self.assertIsInstance(res.json(), list)

    def test_search_category(self):
        # Assuming "Video Games" category exists
        res = requests.get(f"{BASE_URL}/search?category=Video Games")
        self.assertEqual(res.status_code, 200)
        items = res.json()
        if items:
            self.assertEqual(items[0]['category'], "Video Games")

    def test_search_min_rating(self):
        # This might return empty if no ratings, but shouldn't error
        res = requests.get(f"{BASE_URL}/search?min_rating=4.0")
        self.assertEqual(res.status_code, 200)
        items = res.json()
        for item in items:
            self.assertGreaterEqual(item['avg_rating'], 4.0)

if __name__ == '__main__':
    unittest.main()
