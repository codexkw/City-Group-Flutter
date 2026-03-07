# API_CONTRACTS.md — City Group
## REST API ↔ Flutter Contract Reference

> **Rule:** Every endpoint here is the single source of truth.
> Claude Code (.NET) updates this file when adding/changing endpoints.
> Claude Code (Flutter) reads this file before building any screen.
> Never let code drift from this document.

---

## Base URL
```
https://api-city-group.codexkw.co/api/v1
```

## Standard Headers
```
Authorization: Bearer {jwt_token}       ← required on all protected endpoints
Content-Type: application/json
Accept-Language: en | ar | hi           ← controls language of error messages
```

## Standard Response Envelope
```json
{
  "success": true,
  "data": { },
  "message": null,
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 150,
    "totalPages": 8
  }
}
```

## Standard Error Response
```json
{
  "success": false,
  "error": {
    "code": "OUTSIDE_GEOFENCE",
    "message": "You are 250m from the location. Must be within 100m.",
    "details": [ ]
  }
}
```

## Error Codes
| Code | HTTP | Meaning |
|------|------|---------|
| `OUTSIDE_GEOFENCE` | 400 | Not within geofence radius |
| `ALREADY_CHECKED_IN` | 400 | Employee already has active check-in |
| `TASK_IN_PROGRESS` | 400 | Another task already started |
| `PAUSE_REASON_REQUIRED` | 400 | pauseReason field missing or empty |
| `PAUSE_REASON_TEXT_REQUIRED` | 400 | pauseReason=Other but no text provided |
| `GPS_ACCURACY_LOW` | 400 | GPS accuracy > 50 meters |
| `PHOTO_REQUIRED` | 400 | Task requires photo before completing |
| `INVALID_OTP` | 400 | OTP wrong or expired |
| `UNAUTHORIZED` | 401 | Missing or invalid token |
| `FORBIDDEN` | 403 | Role does not have permission |
| `NOT_FOUND` | 404 | Resource not found |
| `TENANT_NOT_FOUND` | 404 | Company not found or inactive |
| `VALIDATION_ERROR` | 422 | Input validation failed (details array populated) |
| `RATE_LIMITED` | 429 | Too many requests |

---

## Role Hierarchy
```
SuperAdmin > Admin > HR > Manager > Supervisor > Employee
[Manager+] means Manager, HR, Admin, SuperAdmin
[Admin+]   means Admin, SuperAdmin
```

---

## ─────────────────────────────────────────
## 1. AUTH
## ─────────────────────────────────────────

### POST /api/v1/auth/login
**Auth:** None (public)
**Flutter screen:** LoginScreen
**Rate limit:** 5 attempts / 15 min per phone number

**Request:**
```json
{
  "phoneNumber": "+96512345678",
  "password": "MyPassword123"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGci...",
    "refreshToken": "d2f3a9b1...",
    "expiresAt": "2026-03-08T10:00:00Z",
    "employee": {
      "id": "guid",
      "fullNameEn": "Ahmed Ali",
      "fullNameAr": "أحمد علي",
      "fullNameHi": "अहमद अली",
      "employeeCode": "EMP001",
      "role": "Employee",
      "language": "ar",
      "profilePhotoUrl": "https://city-group.codexkw.co/uploads/photos/profile/...",
      "companyId": "guid",
      "companyNameEn": "City Group"
    }
  }
}
```

**Errors:** `UNAUTHORIZED` (wrong credentials) | `RATE_LIMITED` | `VALIDATION_ERROR`

---

### POST /api/v1/auth/admin-login
**Auth:** None (public)
**Flutter screen:** N/A (web admin only)

**Request:**
```json
{
  "email": "admin@citygroup.com",
  "password": "AdminPass123"
}
```

**Response 200:** Same envelope as `/auth/login`

---

### POST /api/v1/auth/refresh
**Auth:** None (public)
**Flutter:** Called automatically by ApiClient interceptor on 401

**Request:**
```json
{
  "refreshToken": "d2f3a9b1..."
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGci...",
    "refreshToken": "new_refresh_token...",
    "expiresAt": "2026-03-08T11:00:00Z"
  }
}
```

**Errors:** `UNAUTHORIZED` (refresh token expired/revoked)

---

### POST /api/v1/auth/forgot-password
**Auth:** None (public)
**Flutter screen:** ForgotPasswordScreen — Step 1

**Request:**
```json
{
  "phoneNumber": "+96512345678"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "message": "OTP sent to +965*****678",
    "expiresInMinutes": 10
  }
}
```

**Errors:** `NOT_FOUND` (phone not registered) | `RATE_LIMITED`

---

### POST /api/v1/auth/reset-password
**Auth:** None (public)
**Flutter screen:** ForgotPasswordScreen — Step 3

**Request:**
```json
{
  "phoneNumber": "+96512345678",
  "otp": "847291",
  "newPassword": "NewPass123",
  "confirmPassword": "NewPass123"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": { "message": "Password reset successfully" }
}
```

**Errors:** `INVALID_OTP` | `VALIDATION_ERROR` (passwords don't match)

---

### POST /api/v1/auth/logout
**Auth:** Bearer token required
**Flutter:** Called on profile → logout tap

**Request:**
```json
{
  "refreshToken": "d2f3a9b1..."
}
```

**Response 200:**
```json
{
  "success": true,
  "data": { "message": "Logged out successfully" }
}
```

---

## ─────────────────────────────────────────
## 2. EMPLOYEES
## ─────────────────────────────────────────

### GET /api/v1/employees
**Auth:** [Manager+]
**Flutter screen:** N/A (admin web)

**Query params:**
```
page=1 &pageSize=20
search=ahmed          ← name or employeeCode
role=Employee         ← Employee | Supervisor | Manager | HR | Admin
isActive=true
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "guid",
      "fullNameEn": "Ahmed Ali",
      "fullNameAr": "أحمد علي",
      "fullNameHi": "अहमद अली",
      "employeeCode": "EMP001",
      "phoneNumber": "+96512345678",
      "email": "ahmed@company.com",
      "role": "Employee",
      "isActive": true,
      "profilePhotoUrl": "...",
      "createdAt": "2026-01-01T00:00:00Z"
    }
  ],
  "pagination": { "page": 1, "pageSize": 20, "totalCount": 45, "totalPages": 3 }
}
```

---

### POST /api/v1/employees
**Auth:** [Admin+]

**Request:**
```json
{
  "fullNameEn": "Ahmed Ali",
  "fullNameAr": "أحمد علي",
  "fullNameHi": "अहमद अली",
  "employeeCode": "EMP001",
  "phoneNumber": "+96512345678",
  "email": "ahmed@company.com",
  "role": "Employee",
  "language": "ar"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": "guid",
    "employeeCode": "EMP001",
    "message": "Employee created. Credentials sent via SMS."
  }
}
```

**Errors:** `VALIDATION_ERROR` (phone/code already exists)

---

### GET /api/v1/employees/{id}
**Auth:** [Manager+]

**Response 200:** Full employee object (same as list item + assignedLocations array)

---

### PUT /api/v1/employees/{id}
**Auth:** [Admin+]

**Request:** Same fields as POST (all optional, employeeCode excluded)

**Response 200:**
```json
{
  "success": true,
  "data": { "message": "Employee updated successfully" }
}
```

---

### DELETE /api/v1/employees/{id}
**Auth:** [Admin+]
> Soft deactivate only — sets `IsActive = false`, terminates active sessions

**Response 200:**
```json
{
  "success": true,
  "data": { "message": "Employee deactivated" }
}
```

---

### POST /api/v1/employees/import/preview
**Auth:** [Admin+]
> Dry run — validate Excel file, return errors without creating anything

**Request:** `multipart/form-data` with `file` field (Excel .xlsx)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "validCount": 18,
    "errorCount": 2,
    "errors": [
      { "row": 3, "field": "phoneNumber", "message": "Duplicate phone number" },
      { "row": 7, "field": "email", "message": "Invalid email format" }
    ]
  }
}
```

---

### POST /api/v1/employees/import
**Auth:** [Admin+]
> Actual import — only call after preview confirms acceptable errors

**Request:** `multipart/form-data` with `file` field (Excel .xlsx)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "created": 18,
    "skipped": 2,
    "message": "18 employees created. Credentials sent via SMS."
  }
}
```

---

## ─────────────────────────────────────────
## 3. LOCATIONS
## ─────────────────────────────────────────

### GET /api/v1/locations
**Auth:** [Employee+]
**Flutter screen:** CheckInScreen (to show nearest locations)

**Query params:**
```
isActive=true
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "guid",
      "nameEn": "Head Office",
      "nameAr": "المكتب الرئيسي",
      "nameHi": "मुख्य कार्यालय",
      "address": "Kuwait City",
      "latitude": 29.3759,
      "longitude": 47.9774,
      "geofenceRadius": 100,
      "locationType": "Office",
      "isActive": true
    }
  ]
}
```

---

### POST /api/v1/locations
**Auth:** [Manager+]

**Request:**
```json
{
  "nameEn": "Head Office",
  "nameAr": "المكتب الرئيسي",
  "nameHi": "मुख्य कार्यालय",
  "address": "Kuwait City",
  "latitude": 29.3759,
  "longitude": 47.9774,
  "geofenceRadius": 100,
  "locationType": "Office",
  "operatingStart": "08:00",
  "operatingEnd": "17:00"
}
```

**Response 201:** `{ "success": true, "data": { "id": "guid" } }`

---

### PUT /api/v1/locations/{id}
**Auth:** [Manager+]
**Request:** Same as POST (all optional)
**Response 200:** `{ "success": true, "data": { "message": "Updated" } }`

---

### DELETE /api/v1/locations/{id}
**Auth:** [Admin+]
> Soft delete only
**Response 200:** `{ "success": true, "data": { "message": "Location deactivated" } }`

---

## ─────────────────────────────────────────
## 4. ATTENDANCE
## ─────────────────────────────────────────

### POST /api/v1/attendance/check-in
**Auth:** [Employee]
**Flutter screen:** CheckInScreen

**Request:**
```json
{
  "locationId": "guid",
  "latitude": 29.3759,
  "longitude": 47.9774,
  "accuracy": 12.5,
  "photoBase64": "/9j/4AAQSkZJRgAB..."
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "attendanceId": "guid",
    "checkInTime": "2026-03-07T08:02:00Z",
    "status": "OnTime",
    "locationName": "Head Office",
    "photoUrl": "https://city-group.codexkw.co/uploads/photos/attendance/..."
  }
}
```

**Errors:** `OUTSIDE_GEOFENCE` | `ALREADY_CHECKED_IN` | `GPS_ACCURACY_LOW` | `VALIDATION_ERROR`

**OUTSIDE_GEOFENCE error detail:**
```json
{
  "success": false,
  "error": {
    "code": "OUTSIDE_GEOFENCE",
    "message": "You are 250m from Head Office. Must be within 100m.",
    "details": [
      { "field": "distance", "value": "250" },
      { "field": "required", "value": "100" }
    ]
  }
}
```

---

### POST /api/v1/attendance/check-out
**Auth:** [Employee]
**Flutter screen:** CheckOutScreen

**Request:**
```json
{
  "latitude": 29.3759,
  "longitude": 47.9774,
  "accuracy": 10.0,
  "photoBase64": "/9j/4AAQSkZJRgAB..."
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "attendanceId": "guid",
    "checkOutTime": "2026-03-07T17:05:00Z",
    "totalHours": 8.92,
    "overtimeHours": 0.08,
    "status": "OnTime"
  }
}
```

**Errors:** `NOT_FOUND` (no active check-in) | `GPS_ACCURACY_LOW`

---

### GET /api/v1/attendance/today
**Auth:** [Employee]
**Flutter screen:** HomeScreen (status card)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "isCheckedIn": true,
    "checkInTime": "2026-03-07T08:02:00Z",
    "checkOutTime": null,
    "locationName": "Head Office",
    "elapsedHours": 4.5,
    "status": "OnTime"
  }
}
```

---

### GET /api/v1/attendance/history
**Auth:** [Employee] — own records only
**Flutter screen:** AttendanceHistoryScreen

**Query params:**
```
page=1 & pageSize=20
from=2026-03-01 & to=2026-03-31
locationId=guid         ← optional filter
status=OnTime           ← OnTime | Late | Absent | EarlyDeparture
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "records": [
      {
        "id": "guid",
        "date": "2026-03-07",
        "locationName": "Head Office",
        "checkInTime": "2026-03-07T08:02:00Z",
        "checkOutTime": "2026-03-07T17:05:00Z",
        "totalHours": 8.92,
        "overtimeHours": 0.08,
        "status": "OnTime",
        "checkInPhotoUrl": "...",
        "checkOutPhotoUrl": "..."
      }
    ],
    "summary": {
      "totalDaysWorked": 22,
      "totalHours": 196.24,
      "avgHoursPerDay": 8.92,
      "onTimePercentage": 95.5,
      "lateCount": 1,
      "absentCount": 0
    }
  },
  "pagination": { "page": 1, "pageSize": 20, "totalCount": 22, "totalPages": 2 }
}
```

---

### GET /api/v1/attendance/all
**Auth:** [Manager+]
**Flutter screen:** N/A (admin web dashboard)

**Query params:** Same as `/history` + `employeeId=guid`

**Response 200:** Array of attendance records across all employees (paginated)

---

## ─────────────────────────────────────────
## 5. TASKS
## ─────────────────────────────────────────

### GET /api/v1/tasks/today
**Auth:** [Employee]
**Flutter screen:** TaskListScreen

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "guid",
      "title": "Inspect HVAC Unit",
      "description": "Check filters and log reading",
      "locationId": "guid",
      "locationName": "Head Office",
      "priority": "High",
      "status": "Pending",
      "dueTime": "2026-03-07T12:00:00Z",
      "estimatedMinutes": 45,
      "requirePhoto": true,
      "elapsedSeconds": 0
    }
  ]
}
```

> `title` and `description` returned in the language from `Accept-Language` header.
> `elapsedSeconds` is non-zero if task status is `InProgress`.

---

### GET /api/v1/tasks
**Auth:** [Manager+]

**Query params:**
```
page=1 & pageSize=20
employeeId=guid
locationId=guid
status=Pending          ← Pending | InProgress | Paused | Completed | Cancelled
priority=High
from=2026-03-01 & to=2026-03-31
```

**Response 200:** Paginated array of task objects

---

### POST /api/v1/tasks
**Auth:** [Manager+]

**Request:**
```json
{
  "titleEn": "Inspect HVAC Unit",
  "titleAr": "فحص وحدة التكييف",
  "titleHi": "एचवीएसी यूनिट की जांच करें",
  "descriptionEn": "Check filters and log reading",
  "descriptionAr": "تحقق من الفلاتر وسجل القراءة",
  "descriptionHi": "फ़िल्टर जांचें और रीडिंग लॉग करें",
  "assignedEmployeeId": "guid",
  "locationId": "guid",
  "priority": "High",
  "dueDate": "2026-03-07T12:00:00Z",
  "estimatedMinutes": 45,
  "requirePhoto": true,
  "maxPhotos": 5
}
```

**Response 201:** `{ "success": true, "data": { "id": "guid" } }`

---

### GET /api/v1/tasks/{id}
**Auth:** [Employee+]
**Flutter screen:** TaskDetailScreen

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": "guid",
    "title": "Inspect HVAC Unit",
    "description": "Check filters and log reading",
    "priority": "High",
    "status": "InProgress",
    "startedAt": "2026-03-07T09:15:00Z",
    "dueTime": "2026-03-07T12:00:00Z",
    "elapsedSeconds": 1845,
    "pausedMinutes": 0,
    "requirePhoto": true,
    "photos": [],
    "location": {
      "id": "guid",
      "name": "Head Office",
      "latitude": 29.3759,
      "longitude": 47.9774,
      "geofenceRadius": 100
    },
    "assignedEmployee": {
      "id": "guid",
      "name": "Ahmed Ali"
    }
  }
}
```

---

### PUT /api/v1/tasks/{id}
**Auth:** [Manager+]
**Request:** Any subset of POST fields
**Response 200:** `{ "success": true, "data": { "message": "Updated" } }`

---

### POST /api/v1/tasks/{id}/start
**Auth:** [Employee]
**Flutter screen:** TaskDetailScreen → Start button

**Request:**
```json
{
  "latitude": 29.3759,
  "longitude": 47.9774,
  "accuracy": 8.5
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "taskId": "guid",
    "status": "InProgress",
    "startedAt": "2026-03-07T09:15:00Z"
  }
}
```

**Errors:** `OUTSIDE_GEOFENCE` | `TASK_IN_PROGRESS` | `GPS_ACCURACY_LOW`

---

### POST /api/v1/tasks/{id}/pause
**Auth:** [Employee]
**Flutter screen:** PauseReasonBottomSheet
> ⚠️ `pauseReason` is MANDATORY — reject with 400 if missing

**Request:**
```json
{
  "pauseReason": "Other",
  "pauseReasonText": "Waiting for client representative to arrive"
}
```

> `pauseReason` enum values: `Break` | `WaitingForEquipment` | `WaitingForAccess` | `Emergency` | `CustomerNotAvailable` | `Other`
> `pauseReasonText` required only when `pauseReason = "Other"`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "taskId": "guid",
    "status": "Paused",
    "pausedAt": "2026-03-07T10:00:00Z",
    "pauseReason": "Other",
    "pauseReasonText": "Waiting for client representative to arrive"
  }
}
```

**Errors:** `PAUSE_REASON_REQUIRED` | `PAUSE_REASON_TEXT_REQUIRED`

---

### POST /api/v1/tasks/{id}/resume
**Auth:** [Employee]
**Flutter screen:** TaskDetailScreen → Resume button

**Request:** `{}` (empty body)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "taskId": "guid",
    "status": "InProgress",
    "resumedAt": "2026-03-07T10:30:00Z",
    "totalPausedMinutes": 30
  }
}
```

---

### POST /api/v1/tasks/{id}/complete
**Auth:** [Employee]
**Flutter screen:** TaskCompleteModal

**Request:**
```json
{
  "latitude": 29.3759,
  "longitude": 47.9774,
  "accuracy": 9.0,
  "completionNotes": "All filters replaced. Unit operational.",
  "photos": [
    "/9j/4AAQSkZJRgAB...",
    "/9j/4AAQSkZJRgAC..."
  ]
}
```

> `photos` array required when task `requirePhoto = true`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "taskId": "guid",
    "status": "Completed",
    "completedAt": "2026-03-07T10:45:00Z",
    "actualMinutes": 75,
    "pausedMinutes": 30,
    "netWorkMinutes": 45
  }
}
```

**Errors:** `PHOTO_REQUIRED`

---

### GET /api/v1/tasks/{id}/history
**Auth:** [Manager+]
**Flutter screen:** N/A (admin web)

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "guid",
      "actionType": "Started",
      "performedBy": "Ahmed Ali",
      "timestamp": "2026-03-07T09:15:00Z",
      "latitude": 29.3759,
      "longitude": 47.9774,
      "previousStatus": "Pending",
      "newStatus": "InProgress",
      "pauseReason": null,
      "pauseReasonText": null,
      "photos": [],
      "notes": null
    },
    {
      "id": "guid",
      "actionType": "Paused",
      "performedBy": "Ahmed Ali",
      "timestamp": "2026-03-07T10:00:00Z",
      "latitude": 29.3759,
      "longitude": 47.9774,
      "previousStatus": "InProgress",
      "newStatus": "Paused",
      "pauseReason": "Other",
      "pauseReasonText": "Waiting for client representative",
      "photos": [],
      "notes": null
    }
  ]
}
```

> This list is immutable — entries are never edited or deleted.

---

## ─────────────────────────────────────────
## 6. SPEED LOGS
## ─────────────────────────────────────────

### POST /api/v1/speed-logs/batch
**Auth:** [Employee]
**Flutter screen:** BackgroundSpeedService (automatic, no UI)
> Sent every 5 readings or when task ends. Offline-buffered in local SQLite.

**Request:**
```json
{
  "taskId": "guid",
  "readings": [
    {
      "recordedAt": "2026-03-07T09:15:00Z",
      "speedKmh": 45.2,
      "latitude": 29.3759,
      "longitude": 47.9774
    },
    {
      "recordedAt": "2026-03-07T09:15:30Z",
      "speedKmh": 62.8,
      "latitude": 29.3762,
      "longitude": 47.9780
    }
  ]
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "saved": 2,
    "violations": 1
  }
}
```

> Server automatically flags readings that exceed `CompanySettings.SpeedLimitKmh`.
> If sustained violation ≥ 30 sec → creates notification + FCM to manager.

---

### GET /api/v1/speed-logs
**Auth:** [Manager+]
**Flutter screen:** N/A (admin web)

**Query params:**
```
employeeId=guid
from=2026-03-01 & to=2026-03-31
violationsOnly=true
page=1 & pageSize=50
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "guid",
      "employeeName": "Ahmed Ali",
      "taskId": "guid",
      "recordedAt": "2026-03-07T09:15:30Z",
      "speedKmh": 62.8,
      "latitude": 29.3762,
      "longitude": 47.9780,
      "isViolation": false
    }
  ],
  "pagination": { "page": 1, "pageSize": 50, "totalCount": 120, "totalPages": 3 }
}
```

---

## ─────────────────────────────────────────
## 7. REPORTS
## ─────────────────────────────────────────

> All reports include company branding (logo + colors) in header.
> All responses return a file download URL or binary stream.

### POST /api/v1/reports/attendance
**Auth:** [HR+]

**Request:**
```json
{
  "from": "2026-03-01",
  "to": "2026-03-31",
  "employeeIds": [],
  "locationIds": [],
  "format": "Excel"
}
```

> `employeeIds` and `locationIds` empty = all
> `format`: `"Excel"` | `"PDF"`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "downloadUrl": "https://city-group.codexkw.co/uploads/reports/attendance-2026-03.xlsx",
    "expiresAt": "2026-03-07T11:00:00Z"
  }
}
```

---

### POST /api/v1/reports/tasks
**Auth:** [Manager+]

**Request:**
```json
{
  "from": "2026-03-01",
  "to": "2026-03-31",
  "employeeIds": [],
  "locationIds": [],
  "statusFilter": [],
  "format": "PDF"
}
```

**Response 200:** Same `downloadUrl` envelope

---

### POST /api/v1/reports/task-history
**Auth:** [Manager+]
> Per-customer detailed report with full audit trail

**Request:**
```json
{
  "locationId": "guid",
  "from": "2026-03-01",
  "to": "2026-03-31",
  "includePhotos": true,
  "includePauseDetails": true,
  "format": "PDF"
}
```

**Response 200:** Same `downloadUrl` envelope

---

### POST /api/v1/reports/speed
**Auth:** [Manager+]

**Request:**
```json
{
  "from": "2026-03-01",
  "to": "2026-03-31",
  "employeeIds": [],
  "violationsOnly": false,
  "format": "Excel"
}
```

**Response 200:** Same `downloadUrl` envelope

---

## ─────────────────────────────────────────
## 8. NOTIFICATIONS
## ─────────────────────────────────────────

### GET /api/v1/notifications
**Auth:** [Employee+]
**Flutter screen:** NotificationsScreen

**Query params:**
```
page=1 & pageSize=20
isRead=false
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "unreadCount": 3,
    "notifications": [
      {
        "id": "guid",
        "title": "New Task Assigned",
        "body": "Inspect HVAC Unit at Head Office by 12:00 PM",
        "type": "TaskAssigned",
        "referenceId": "task-guid",
        "isRead": false,
        "createdAt": "2026-03-07T08:00:00Z"
      }
    ]
  },
  "pagination": { "page": 1, "pageSize": 20, "totalCount": 12, "totalPages": 1 }
}
```

> `type` values: `TaskAssigned` | `LateCheckIn` | `TaskOverdue` | `SpeedViolation` | `System`
> `referenceId` is the `taskId` or `attendanceId` to deep-link to

---

### PUT /api/v1/notifications/{id}/read
**Auth:** [Employee+]
**Flutter:** Tap on notification

**Response 200:** `{ "success": true, "data": { "message": "Marked as read" } }`

---

### PUT /api/v1/notifications/read-all
**Auth:** [Employee+]
**Flutter:** "Mark all read" button

**Response 200:** `{ "success": true, "data": { "marked": 3 } }`

---

## ─────────────────────────────────────────
## 9. PROFILE
## ─────────────────────────────────────────

### GET /api/v1/profile
**Auth:** [Employee+]
**Flutter screen:** ProfileScreen

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": "guid",
    "fullNameEn": "Ahmed Ali",
    "fullNameAr": "أحمد علي",
    "fullNameHi": "अहमद अली",
    "employeeCode": "EMP001",
    "phoneNumber": "+96512345678",
    "email": "ahmed@company.com",
    "role": "Employee",
    "language": "ar",
    "profilePhotoUrl": "...",
    "companyName": "City Group",
    "assignedLocations": [
      { "id": "guid", "name": "Head Office" }
    ]
  }
}
```

---

### PUT /api/v1/profile
**Auth:** [Employee+]
**Flutter screen:** ProfileScreen → Edit

**Request:**
```json
{
  "email": "newemail@company.com",
  "profilePhotoBase64": "/9j/4AAQSkZJRgAB..."
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "profilePhotoUrl": "https://city-group.codexkw.co/uploads/photos/profile/..."
  }
}
```

---

### PUT /api/v1/profile/language
**Auth:** [Employee+]
**Flutter screen:** LanguageSettingsScreen

**Request:**
```json
{
  "language": "ar"
}
```

> `language` values: `"en"` | `"ar"` | `"hi"`

**Response 200:** `{ "success": true, "data": { "language": "ar" } }`

---

### PUT /api/v1/profile/password
**Auth:** [Employee+]
**Flutter screen:** ChangePasswordScreen

**Request:**
```json
{
  "currentPassword": "OldPass123",
  "newPassword": "NewPass456",
  "confirmPassword": "NewPass456"
}
```

**Response 200:** `{ "success": true, "data": { "message": "Password changed" } }`

**Errors:** `UNAUTHORIZED` (wrong current password) | `VALIDATION_ERROR` (passwords don't match)

---

### PUT /api/v1/profile/fcm-token
**Auth:** [Employee+]
**Flutter:** Called automatically after login and when FCM token refreshes

**Request:**
```json
{
  "fcmToken": "fHjK2mN..."
}
```

**Response 200:** `{ "success": true, "data": { "message": "FCM token registered" } }`

---

## ─────────────────────────────────────────
## 10. COMPANIES (Super Admin)
## ─────────────────────────────────────────

### GET /api/v1/companies
**Auth:** [SuperAdmin]

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "guid",
      "nameEn": "City Group",
      "nameAr": "سيتي جروب",
      "nameHi": "सिटी ग्रुप",
      "companyCode": "CITY01",
      "isActive": true,
      "employeeCount": 45,
      "locationCount": 8,
      "logoUrl": "...",
      "lastActivityAt": "2026-03-07T10:00:00Z"
    }
  ]
}
```

---

### POST /api/v1/companies
**Auth:** [SuperAdmin]

**Request:**
```json
{
  "nameEn": "City Group",
  "nameAr": "سيتي جروب",
  "nameHi": "सिटी ग्रुप",
  "companyCode": "CITY01",
  "contactEmail": "admin@citygroup.com",
  "contactPhone": "+96512345678",
  "address": "Kuwait City"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": "guid",
    "message": "Company created. Admin credentials sent to admin@citygroup.com"
  }
}
```

---

### PUT /api/v1/companies/{id}
**Auth:** [Admin+]
**Request:** Subset of POST fields
**Response 200:** `{ "success": true, "data": { "message": "Updated" } }`

---

### POST /api/v1/companies/{id}/logo
**Auth:** [Admin+]
**Flutter screen:** N/A (admin web)

**Request:** `multipart/form-data` with `logo` field (PNG/JPG/SVG, max 2MB)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "logoUrl": "https://city-group.codexkw.co/uploads/logos/{tenantId}/logo.png"
  }
}
```

---

### PUT /api/v1/companies/{id}/branding
**Auth:** [Admin+]

**Request:**
```json
{
  "primaryColor": "#1B3A6D",
  "secondaryColor": "#C9A227",
  "accentColor": "#FFFFFF",
  "logoPosition": "Left",
  "reportFooterText": "City Group © 2026",
  "showWatermark": false
}
```

**Response 200:** `{ "success": true, "data": { "message": "Branding updated" } }`

---

## ─────────────────────────────────────────
## FLUTTER ↔ ENDPOINT QUICK REFERENCE
## ─────────────────────────────────────────

| Flutter Screen / Service | Endpoints Used |
|--------------------------|---------------|
| LoginScreen | `POST /auth/login` |
| BiometricScreen | Uses stored JWT (no API call) |
| ForgotPasswordScreen | `POST /auth/forgot-password` + `POST /auth/reset-password` |
| HomeScreen | `GET /attendance/today` + `GET /tasks/today` + `GET /notifications` |
| CheckInScreen | `GET /locations` + `POST /attendance/check-in` |
| CheckOutScreen | `POST /attendance/check-out` |
| AttendanceHistoryScreen | `GET /attendance/history` |
| TaskListScreen | `GET /tasks/today` |
| TaskDetailScreen | `GET /tasks/{id}` + `POST /tasks/{id}/start` |
| PauseReasonBottomSheet | `POST /tasks/{id}/pause` |
| TaskDetailScreen (resume) | `POST /tasks/{id}/resume` |
| TaskCompleteModal | `POST /tasks/{id}/complete` |
| NotificationsScreen | `GET /notifications` + `PUT /notifications/{id}/read` + `PUT /notifications/read-all` |
| ProfileScreen | `GET /profile` + `PUT /profile` |
| LanguageSettingsScreen | `PUT /profile/language` |
| ChangePasswordScreen | `PUT /profile/password` |
| BackgroundSpeedService | `POST /speed-logs/batch` (automatic, background) |
| App startup | `PUT /profile/fcm-token` (after login) + `POST /auth/refresh` (on 401) |

---

*Last updated: March 2026 | Endpoints: 35 | Base URL: https://api-city-group.codexkw.co/api/v1*
