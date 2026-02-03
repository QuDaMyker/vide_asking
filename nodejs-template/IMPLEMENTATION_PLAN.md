# Implementation Plan: Standardized ApiResponse Pattern

## Problem Statement
The codebase currently has inconsistent API response formats across different endpoints:
- Success responses: `{status: 'success', data: {...}}`
- Error responses: `{status: 'error', statusCode: 400, message: '...'}`
- Health check: `{status: 'ok', timestamp: ..., uptime: ...}`

**Goal**: Implement a consistent ApiResponse pattern across all endpoints with the structure:
```typescript
{
  status: number,      // HTTP status code (200, 201, 400, 404, 500, etc.)
  message: string,     // Human-readable message ('Success', 'Created', 'Invalid credentials', etc.)
  metadata: any        // For success: actual data; For errors: error details/validation errors
}
```

## User Requirements (Confirmed)
- ✅ `status` field = HTTP status code (200, 201, 400, etc.)
- ✅ Apply to BOTH success AND error responses
- ✅ `metadata` field: For success = actual data; For errors = error details/validation errors
- ✅ Refactor ALL existing endpoints to use the new pattern

---

## Workplan

### Phase 1: Create Core Utilities
- [ ] Create `src/utils/apiResponse.ts` with:
  - `ApiResponse` TypeScript interface
  - `sendSuccess()` helper function for success responses
  - `sendError()` helper function for error responses
  - `sendCreated()` helper for 201 responses
  - `sendNotFound()` helper for 404 responses
  - `sendValidationError()` helper for 400 validation errors

### Phase 2: Create Type Definitions
- [ ] Create or update `src/types/response.types.ts` with:
  - `ApiResponse<T>` generic interface
  - `SuccessResponse<T>` type
  - `ErrorResponse` type
  - `ValidationErrorDetails` interface (for express-validator errors)

### Phase 3: Update Middleware
- [ ] Update `src/middleware/errorHandler.ts`:
  - Use new `sendError()` function
  - Format errors as `{status: Int, message: String, metadata: {...}}`
  - Handle different error types (AppError, ValidationError, JWT errors, etc.)
  - Preserve stack traces in development mode within metadata
  
- [ ] Update `src/middleware/notFoundHandler.ts`:
  - Use new `sendNotFound()` function
  - Format as `{status: 404, message: 'Route not found', metadata: {path: '...'}}`

### Phase 4: Update Controllers
- [ ] Update `src/controllers/authController.ts`:
  - `register()`: Use `sendCreated()` with message 'User registered successfully'
  - `login()`: Use `sendSuccess()` with message 'Login successful'
  - `refreshToken()`: Use `sendSuccess()` with message 'Token refreshed'
  - `getProfile()`: Use `sendSuccess()` with message 'Profile retrieved'
  - Update error handling to use new pattern

### Phase 5: Update Application Endpoints
- [ ] Update `src/app.ts`:
  - Health check endpoint: Use `sendSuccess()` with consistent format
  - Include uptime and timestamp in metadata

### Phase 6: Documentation
- [ ] Update `API_DOCUMENTATION.md`:
  - Document the new ApiResponse structure
  - Provide examples for success responses
  - Provide examples for error responses
  - Update all endpoint documentation with new response format
  
- [ ] Update `README.md`:
  - Add section explaining the standardized response pattern
  - Provide usage examples

### Phase 7: Testing
- [ ] Update test files in `tests/`:
  - Update test assertions to expect new response format
  - Add tests for the new utility functions
  - Verify all endpoints return correct format

- [ ] Manual testing:
  - Test health endpoint
  - Test all auth endpoints (register, login, refresh, profile)
  - Test error scenarios (404, 401, 400, 500)
  - Test validation errors

### Phase 8: Code Quality
- [ ] Run linter and fix any issues:
  ```bash
  npm run lint:fix
  ```
  
- [ ] Run tests and ensure all pass:
  ```bash
  npm test
  ```

---

## Implementation Details

### Proposed ApiResponse Utility Structure

```typescript
// src/utils/apiResponse.ts
interface ApiResponse<T = any> {
  status: number;
  message: string;
  metadata: T;
}

export const sendSuccess = <T>(
  res: Response, 
  data: T, 
  message: string = 'Success',
  statusCode: number = 200
): Response => {
  return res.status(statusCode).json({
    status: statusCode,
    message,
    metadata: data
  });
};

export const sendError = (
  res: Response,
  message: string,
  statusCode: number = 500,
  errorDetails?: any
): Response => {
  return res.status(statusCode).json({
    status: statusCode,
    message,
    metadata: errorDetails || null
  });
};
```

### Response Format Examples

**Success Response (200):**
```json
{
  "status": 200,
  "message": "Login successful",
  "metadata": {
    "user": { "id": 1, "email": "user@example.com" },
    "accessToken": "...",
    "refreshToken": "..."
  }
}
```

**Created Response (201):**
```json
{
  "status": 201,
  "message": "User registered successfully",
  "metadata": {
    "user": { "id": 1, "email": "user@example.com" }
  }
}
```

**Validation Error (400):**
```json
{
  "status": 400,
  "message": "Validation failed",
  "metadata": {
    "errors": [
      { "field": "email", "message": "Invalid email format" },
      { "field": "password", "message": "Password must be at least 8 characters" }
    ]
  }
}
```

**Not Found Error (404):**
```json
{
  "status": 404,
  "message": "Route not found",
  "metadata": {
    "path": "/api/unknown"
  }
}
```

**Server Error (500):**
```json
{
  "status": 500,
  "message": "Internal server error",
  "metadata": null
}
```

---

## Files to Create/Modify

### New Files:
1. `src/utils/apiResponse.ts` - Response utility functions
2. `src/types/response.types.ts` - TypeScript type definitions

### Modified Files:
1. `src/middleware/errorHandler.ts` - Use new response pattern
2. `src/middleware/notFoundHandler.ts` - Use new response pattern
3. `src/controllers/authController.ts` - Update all responses
4. `src/app.ts` - Update health endpoint
5. `API_DOCUMENTATION.md` - Document new response format
6. `README.md` - Add response pattern section
7. `tests/*.test.ts` - Update test expectations

---

## Success Criteria

✅ All API responses follow the exact format: `{status: Int, message: String, metadata: Data}`
✅ Response utilities are reusable and type-safe
✅ Error handling is consistent across all error types
✅ All existing endpoints are refactored
✅ Documentation is updated with new format
✅ All tests pass
✅ Code quality checks pass (linting)

---

## Estimated Impact

- **Files to modify**: ~7-8 files
- **Files to create**: 2 new utility files
- **Breaking change**: Yes - API clients may need updates
- **Backward compatibility**: No - response format changes completely

---

## Notes

- This is a **breaking change** for any existing API consumers
- Consider versioning the API (e.g., `/api/v2/`) if backward compatibility is needed
- The `metadata` field name is flexible - could be renamed to `data` or `payload` if preferred
- Development stack traces will be included in error metadata for debugging
- HTTP status codes will be duplicated (in both HTTP response status AND body.status) for consistency
