# API Documentation

Complete API reference for the Express + TypeScript backend.

## Base URL

```
http://localhost:3000
```

## Authentication

Most endpoints require authentication using JWT (JSON Web Tokens).

Include the access token in the Authorization header:
```
Authorization: Bearer <your_access_token>
```

---

## Endpoints

### Health Check

Check if the API is running.

**Endpoint:** `GET /health`

**Authentication:** Not required

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2026-02-03T09:53:39.000Z",
  "uptime": 123.456
}
```

**Status Codes:**
- `200 OK` - Server is healthy

---

## Authentication Endpoints

### Register New User

Create a new user account.

**Endpoint:** `POST /api/auth/register`

**Authentication:** Not required

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123",
  "firstName": "John",
  "lastName": "Doe"
}
```

**Validation Rules:**
- `email`: Must be a valid email address
- `password`: Minimum 8 characters, must contain uppercase, lowercase, and number
- `firstName`: 2-50 characters
- `lastName`: 2-50 characters

**Success Response (201):**
```json
{
  "status": "success",
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "isActive": true,
      "lastLogin": null,
      "createdAt": "2026-02-03T09:53:39.000Z",
      "updatedAt": "2026-02-03T09:53:39.000Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error Responses:**

`400 Bad Request` - Validation failed
```json
{
  "status": "error",
  "statusCode": 400,
  "message": "Password must be at least 8 characters long"
}
```

`400 Bad Request` - User already exists
```json
{
  "status": "error",
  "statusCode": 400,
  "message": "User with this email already exists"
}
```

**Rate Limit:** 5 requests per 15 minutes

**cURL Example:**
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.doe@example.com",
    "password": "SecurePass123",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

---

### Login

Authenticate and receive access tokens.

**Endpoint:** `POST /api/auth/login`

**Authentication:** Not required

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123"
}
```

**Success Response (200):**
```json
{
  "status": "success",
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "isActive": true,
      "lastLogin": "2026-02-03T09:53:39.000Z",
      "createdAt": "2026-02-03T09:53:39.000Z",
      "updatedAt": "2026-02-03T09:53:39.000Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error Responses:**

`401 Unauthorized` - Invalid credentials
```json
{
  "status": "error",
  "statusCode": 401,
  "message": "Invalid credentials"
}
```

`401 Unauthorized` - Account deactivated
```json
{
  "status": "error",
  "statusCode": 401,
  "message": "User account is deactivated"
}
```

**Rate Limit:** 5 requests per 15 minutes

**cURL Example:**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.doe@example.com",
    "password": "SecurePass123"
  }'
```

---

### Get User Profile

Retrieve authenticated user's profile.

**Endpoint:** `GET /api/auth/profile`

**Authentication:** Required

**Headers:**
```
Authorization: Bearer <access_token>
```

**Success Response (200):**
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "isActive": true,
    "lastLogin": "2026-02-03T09:53:39.000Z",
    "createdAt": "2026-02-03T09:53:39.000Z",
    "updatedAt": "2026-02-03T09:53:39.000Z"
  }
}
```

**Error Responses:**

`401 Unauthorized` - No token provided
```json
{
  "status": "error",
  "statusCode": 401,
  "message": "No token provided"
}
```

`401 Unauthorized` - Invalid token
```json
{
  "status": "error",
  "statusCode": 401,
  "message": "Invalid token"
}
```

`401 Unauthorized` - Token expired
```json
{
  "status": "error",
  "statusCode": 401,
  "message": "Token expired"
}
```

**cURL Example:**
```bash
curl -X GET http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

### Refresh Access Token

Get a new access token using a refresh token.

**Endpoint:** `POST /api/auth/refresh-token`

**Authentication:** Not required (uses refresh token)

**Request Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response (200):**
```json
{
  "status": "success",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error Responses:**

`400 Bad Request` - Missing refresh token
```json
{
  "status": "error",
  "message": "Refresh token is required"
}
```

`401 Unauthorized` - Invalid refresh token
```json
{
  "status": "error",
  "statusCode": 401,
  "message": "Invalid refresh token"
}
```

**cURL Example:**
```bash
curl -X POST http://localhost:3000/api/auth/refresh-token \
  -H "Content-Type: application/json" \
  -d '{
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

---

## Error Response Format

All error responses follow this format:

```json
{
  "status": "error",
  "statusCode": 400,
  "message": "Error message here"
}
```

In development mode, a `stack` property may be included with the stack trace.

---

## HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | OK - Request succeeded |
| 201 | Created - Resource created successfully |
| 400 | Bad Request - Invalid input or validation error |
| 401 | Unauthorized - Authentication required or failed |
| 404 | Not Found - Resource or endpoint not found |
| 429 | Too Many Requests - Rate limit exceeded |
| 500 | Internal Server Error - Server error |

---

## Rate Limiting

Rate limits are applied to prevent abuse:

**Global Rate Limit:**
- 100 requests per 15 minutes per IP

**Authentication Endpoints:**
- 5 requests per 15 minutes per IP

When rate limit is exceeded:
```json
{
  "status": "error",
  "statusCode": 429,
  "message": "Too many requests from this IP, please try again later."
}
```

---

## Security Headers

All responses include security headers:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security` (in production)

---

## CORS

Cross-Origin Resource Sharing is enabled. Configure allowed origins in the `.env` file:

```env
CORS_ORIGIN=http://localhost:3001,https://yourdomain.com
```

Or use `*` for development to allow all origins.

---

## Token Expiration

**Access Token:**
- Default expiration: 24 hours
- Configurable via `JWT_EXPIRES_IN` in `.env`

**Refresh Token:**
- Default expiration: 7 days
- Configurable via `JWT_REFRESH_EXPIRES_IN` in `.env`

---

## Postman Collection

You can create a Postman collection with these endpoints:

1. **Create a new collection** named "Express TypeScript API"

2. **Add environment variables:**
   - `base_url`: `http://localhost:3000`
   - `access_token`: (will be set automatically)
   - `refresh_token`: (will be set automatically)

3. **Add requests:**
   - Health Check: `GET {{base_url}}/health`
   - Register: `POST {{base_url}}/api/auth/register`
   - Login: `POST {{base_url}}/api/auth/login`
   - Profile: `GET {{base_url}}/api/auth/profile` (with Bearer token)
   - Refresh Token: `POST {{base_url}}/api/auth/refresh-token`

4. **Add test scripts** to save tokens automatically:

For Register/Login endpoints, add this test script:
```javascript
if (pm.response.code === 200 || pm.response.code === 201) {
    const response = pm.response.json();
    pm.environment.set("access_token", response.data.accessToken);
    pm.environment.set("refresh_token", response.data.refreshToken);
}
```

---

## Examples with Different Languages

### JavaScript (Fetch)

```javascript
// Register
const response = await fetch('http://localhost:3000/api/auth/register', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'SecurePass123',
    firstName: 'John',
    lastName: 'Doe'
  })
});
const data = await response.json();
```

### Python (Requests)

```python
import requests

# Register
response = requests.post(
    'http://localhost:3000/api/auth/register',
    json={
        'email': 'user@example.com',
        'password': 'SecurePass123',
        'firstName': 'John',
        'lastName': 'Doe'
    }
)
data = response.json()
```

### PHP

```php
<?php
// Register
$ch = curl_init('http://localhost:3000/api/auth/register');
curl_setopt($ch, CURLOPT_POST, 1);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'email' => 'user@example.com',
    'password' => 'SecurePass123',
    'firstName' => 'John',
    'lastName' => 'Doe'
]));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = curl_exec($ch);
curl_close($ch);
$data = json_decode($response, true);
?>
```

---

## Need Help?

- See [GETTING_STARTED.md](./GETTING_STARTED.md) for setup instructions
- See [README.md](./README.md) for project overview
- Check the troubleshooting section in GETTING_STARTED.md
