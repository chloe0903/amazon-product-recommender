import requests
import unittest

BASE_URL = "http://localhost:8000"

class TestCRUD(unittest.TestCase):
    def setUp(self):
        # Clean up before test
        requests.delete(f"{BASE_URL}/product/UNIT_TEST_ASIN")

    def tearDown(self):
        # Clean up after test
        requests.delete(f"{BASE_URL}/product/UNIT_TEST_ASIN")

    def test_create_read_update_delete(self):
        # 1. Create
        product_data = {
            "asin": "UNIT_TEST_ASIN",
            "name": "Unit Test Product",
            "category": "Electronics",
            "store_id": "Test Store",
            "price": 50.00
        }
        res = requests.post(f"{BASE_URL}/product", json=product_data)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data['name'], "Unit Test Product")

        # 2. Read
        res = requests.get(f"{BASE_URL}/product/UNIT_TEST_ASIN")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data['asin'], "UNIT_TEST_ASIN")

        # 3. Update
        update_data = {"name": "Updated Unit Test Product", "price": 45.00}
        res = requests.put(f"{BASE_URL}/product/UNIT_TEST_ASIN", json=update_data)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data['name'], "Updated Unit Test Product")
        self.assertEqual(data['price'], 45.00)

        # 4. Delete
        res = requests.delete(f"{BASE_URL}/product/UNIT_TEST_ASIN")
        self.assertEqual(res.status_code, 200)

        # Verify Delete
        res = requests.get(f"{BASE_URL}/product/UNIT_TEST_ASIN")
        self.assertEqual(res.status_code, 404)

if __name__ == '__main__':
    unittest.main()
