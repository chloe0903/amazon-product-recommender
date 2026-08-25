// server.js
const express = require("express");
const axios = require("axios");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

const API_BASE = process.env.API_BASE || "http://localhost:8000";

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(express.static(path.join(__dirname, "public")));

app.get("/api/search", async (req, res) => {
  const { q, category, min_rating } = req.query;
  try {
    const response = await axios.get(`${API_BASE}/search`, {
      params: { q, category, min_rating },
    });
    res.json(response.data);
  } catch (err) {
    console.error("Error calling backend /search:", err.message);
    res.status(500).json({ error: "Failed to contact backend" });
  }
});

app.get("/api/product/:asin", async (req, res) => {
  try {
    const response = await axios.get(`${API_BASE}/product/${req.params.asin}`);
    res.json(response.data);
  } catch (err) {
    res.status(err.response?.status || 500).json(err.response?.data || { error: "Product not found" });
  }
});

// CRUD Proxy
app.post("/api/product", async (req, res) => {
  try {
    const response = await axios.post(`${API_BASE}/product`, req.body);
    res.json(response.data);
  } catch (err) {
    res.status(err.response?.status || 500).json(err.response?.data || { error: "Failed to create product" });
  }
});

app.put("/api/product/:asin", async (req, res) => {
  try {
    const response = await axios.put(`${API_BASE}/product/${req.params.asin}`, req.body);
    res.json(response.data);
  } catch (err) {
    res.status(err.response?.status || 500).json(err.response?.data || { error: "Failed to update product" });
  }
});

app.delete("/api/product/:asin", async (req, res) => {
  try {
    const response = await axios.delete(`${API_BASE}/product/${req.params.asin}`);
    res.json(response.data);
  } catch (err) {
    res.status(err.response?.status || 500).json(err.response?.data || { error: "Failed to delete product" });
  }
});

// Advanced Features Proxy
app.post("/api/purchase", async (req, res) => {
  try {
    const response = await axios.post(`${API_BASE}/purchase`, req.body);
    res.json(response.data);
  } catch (err) {
    res.status(err.response?.status || 500).json(err.response?.data || { error: "Purchase failed" });
  }
});

app.get("/api/top-products", async (req, res) => {
  try {
    const response = await axios.get(`${API_BASE}/top-products`, { params: req.query });
    res.json(response.data);
  } catch (err) {
    res.status(err.response?.status || 500).json(err.response?.data || { error: "Failed to fetch top products" });
  }
});

app.get("/api/purchased-products/:buyer_id", async (req, res) => {
  try {
    const response = await axios.get(`${API_BASE}/purchased-products/${req.params.buyer_id}`);
    res.json(response.data);
  } catch (err) {
    res.status(err.response?.status || 500).json(err.response?.data || { error: "Failed to fetch purchased products" });
  }
});

app.post("/api/review", async (req, res) => {
  try {
    const response = await axios.post(`${API_BASE}/review`, req.body);
    res.json(response.data);
  } catch (err) {
    res.status(err.response?.status || 500).json(err.response?.data || { error: "Failed to submit review" });
  }
});

app.listen(PORT, () => {
  console.log(`Frontend server running at http://localhost:${PORT}`);
  console.log(`Using backend API at ${API_BASE}`);
});
