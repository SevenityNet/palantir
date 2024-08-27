# Palantir
Palantir is an API leveraging sentence-transformers/all-MiniLM-L6-v2 and hugot to offer a simple API for generating vector embeddings of text.

## Envs:
- `PORT`: Port to run the server on. Default: `8080`
- `CORS_ALLOWED_ORIGINS`: A valid URL to allow CORS requests from. Default: `*`
- `AUTH_KEY`: Protects the API with a key. Requests without X-API-KEY header will be rejected. Default: `None`