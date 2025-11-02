# Mobile App API Contract Documentation

This document outlines all API endpoints used by the mobile app, including request formats, response formats, and expected data structures.

---

## Table of Contents
1. [Authentication](#authentication)
2. [Exams](#exams)
3. [Exam Attempts](#exam-attempts)
4. [Results](#results)
5. [Data Structures](#data-structures)

---

## Base Configuration

**Base URL:** `http://127.0.0.1:8000/api`  
**Timeout:** 10 seconds  
**Headers:**
```
Content-Type: application/json
Accept: application/json
Authorization: Bearer {token}
```

---

## Authentication

### 1. Login
**Endpoint:** `POST /login`

**Request Body:**
```json
{
  "id_number": "2024-001",
  "password": "student_password",
  "device_name": "mobile-app"
}
```

**Success Response (200):**
```json
{
  "token": "1|abc123...",
  "user": {
    "id": 38,
    "id_number": "2024-001",
    "first_name": "John",
    "last_name": "Doe",
    "email": "john.doe@example.com"
  }
}
```

**Error Response (401):**
```json
{
  "message": "Invalid credentials"
}
```

**Mobile App Usage:**
- Stores token in `ApiService._authToken` and Hive (`auth_token`)
- Stores user data in Hive (`current_user`)
- Extracts database ID (`user['id']`) for API calls
- Combines `first_name + last_name` for display

---

### 2. Get Current User
**Endpoint:** `GET /user`

**Headers:** Requires `Authorization: Bearer {token}`

**Success Response (200):**
```json
{
  "id": 38,
  "id_number": "2024-001",
  "first_name": "John",
  "last_name": "Doe",
  "email": "john.doe@example.com"
}
```

---

### 3. Logout
**Endpoint:** `POST /logout`

**Headers:** Requires `Authorization: Bearer {token}`

**Success Response (200):**
```json
{
  "message": "Logged out successfully"
}
```

**Mobile App Actions:**
- Clears `ApiService._authToken`
- Removes `auth_token` from Hive
- Navigates to login screen

---

## Exams

### 1. Fetch Exams
**Endpoint:** `GET /exams`

**Headers:** Requires `Authorization: Bearer {token}`

**Success Response (200):**
```json
{
  "exams": [
    {
      "exam_id": 3,
      "assignment_id": 15,
      "title": "Midterm Exam",
      "description": "Covers chapters 1-5",
      "status": "approved",
      "schedule_start": "2025-11-01T08:00:00Z",
      "schedule_end": "2025-11-01T10:00:00Z",
      "duration": 120,
      "duration_seconds": 7200,
      "total_points": 100,
      "no_of_items": 50,
      "requiresOtp": true,
      "password": "exam123",
      "resultsReleased": false,
      "allowReview": true,
      "subject": {
        "name": "Mathematics",
        "code": "MATH101"
      },
      "class": {
        "id": 5,
        "name": "Grade 10 - Section A"
      },
      "attempt": {
        "attempt_id": 19,
        "status": "submitted",
        "score": 85,
        "submitted_at": "2025-11-01T09:45:00Z"
      }
    }
  ]
}
```

**Mobile App Processing:**
- Filters exams by `status`: only shows "approved" or "on-going"
- Determines `available`: `true` if not submitted yet
- Determines `inSchedule`: checks if current time is between `schedule_start` and `schedule_end`
- Stores in Hive with `recordType: 'exam'`
- Key format: `meta_{examId}_{studentId}`

---

### 2. Fetch Exam Details
**Endpoint:** `GET /exams/{examId}`

**Headers:** Requires `Authorization: Bearer {token}`

**Success Response (200):**
```json
{
  "exam": {
    "exam_id": 3,
    "title": "Midterm Exam",
    "description": "Covers chapters 1-5",
    "duration": 120,
    "sections": [
      {
        "section_id": 1,
        "title": "Multiple Choice",
        "directions": "Choose the best answer",
        "order": 1,
        "items": [
          {
            "item_id": 6,
            "item_type": "mcq",
            "question": "What is 2 + 2?",
            "options": {
              "A": "3",
              "B": "4",
              "C": "5",
              "D": "6"
            },
            "points_awarded": 1,
            "order": 1
          },
          {
            "item_id": 7,
            "item_type": "torf",
            "question": "The Earth is flat.",
            "options": {
              "True": "True",
              "False": "False"
            },
            "points_awarded": 1,
            "order": 2
          },
          {
            "item_id": 8,
            "item_type": "iden",
            "question": "Who invented the telephone?",
            "options": null,
            "points_awarded": 2,
            "order": 3
          },
          {
            "item_id": 9,
            "item_type": "enum_ordered",
            "question": "List the steps of scientific method in order.",
            "options": null,
            "points_awarded": 5,
            "order": 4
          },
          {
            "item_id": 10,
            "item_type": "essay",
            "question": "Explain the concept of photosynthesis.",
            "options": null,
            "points_awarded": 10,
            "order": 5
          }
        ]
      }
    ]
  }
}
```

**Mobile App Processing:**

**Question Type Mapping:**
- `mcq` → `mcq`
- `torf` → `true_false`
- `iden` → `identification`
- `enum` → `enumeration`
- `enum_ordered` → `enumeration` (preserves `originalType: 'enum_ordered'`)
- `enum_unordered` → `enumeration` (preserves `originalType: 'enum_unordered'`)
- `essay` → `essay`

**Options Processing:**
- If `options` is a Map: converts to array of `{key, text}` objects
  - Example: `{"A": "Paris", "B": "London"}` → `[{key: "A", text: "Paris"}, {key: "B", text: "London"}]`
- If `options` is an Array: auto-generates keys A, B, C, D...
  - Example: `["Paris", "London"]` → `[{key: "A", text: "Paris"}, {key: "B", text: "London"}]`
- Numeric keys are converted to letters (0→A, 1→B, etc.)

**Final Question Structure:**
```json
{
  "id": "item_6",
  "itemId": 6,
  "sectionId": 1,
  "sectionTitle": "Multiple Choice",
  "directions": "Choose the best answer",
  "type": "mcq",
  "originalType": "mcq",
  "question": "What is 2 + 2?",
  "choices": [
    {"key": "A", "text": "3"},
    {"key": "B", "text": "4"},
    {"key": "C", "text": "5"},
    {"key": "D", "text": "6"}
  ],
  "correct": null,
  "marks": 1,
  "order": 1
}
```

---

### 3. Verify Exam Password
**Endpoint:** `POST /exams/{examId}/verify-otp`

**Request Body:**
```json
{
  "studentId": 38,
  "otp": "exam123"
}
```

**Success Response (200):**
```json
{
  "verified": true
}
```

**Failure Response (200):**
```json
{
  "verified": false
}
```

**Mobile App Usage:**
- Shows password verification screen if `requiresOtp: true`
- Blocks exam/results access until verified

---

## Exam Attempts

### 1. Start Exam Attempt
**Endpoint:** `POST /exam-attempts`

**Request Body:**
```json
{
  "exam_assignment_id": 15
}
```

**Success Response (201 - New Attempt):**
```json
{
  "message": "Exam attempt started",
  "attempt": {
    "attempt_id": 19,
    "student_id": 38,
    "exam_assignment_id": 15,
    "status": "in_progress",
    "started_at": "2025-11-01T08:15:00Z"
  }
}
```

**Success Response (200 - Resume Existing):**
```json
{
  "message": "Resuming existing attempt",
  "attempt": {
    "attempt_id": 19,
    "student_id": 38,
    "exam_assignment_id": 15,
    "status": "in_progress",
    "started_at": "2025-11-01T08:15:00Z"
  }
}
```

**Error Response (400):**
```json
{
  "message": "Exam already completed"
}
```

**Error Response (403):**
```json
{
  "message": "Exam not yet available"
}
```

**Mobile App Usage:**
- Stores `attempt_id` in state
- Uses for all subsequent submission calls
- Saves attempt to Hive for offline recovery

---

### 2. Submit Exam Attempt
**Endpoint:** `POST /exam-attempts/{attemptId}/submit`

**Request Body:**
```json
{
  "duration_taken": 5400,
  "answers": [
    {
      "item_id": 6,
      "answer": "B"
    },
    {
      "item_id": 7,
      "answer": "False"
    },
    {
      "item_id": 8,
      "answer": "Alexander Graham Bell"
    },
    {
      "item_id": 9,
      "answer": "A,C,D"
    },
    {
      "item_id": 10,
      "answer": "Photosynthesis is the process by which plants..."
    }
  ]
}
```

**Answer Format by Question Type:**
- **MCQ (Single):** `"B"` (option key)
- **MCQ (Multiple):** `"A,B,D"` (comma-separated option keys)
- **True/False:** `"True"` or `"False"` (capitalized)
- **Identification:** `"Alexander Graham Bell"` (text)
- **Enumeration:** `"Item 1, Item 2, Item 3"` (text, comma-separated)
- **Essay:** `"Long form text answer..."` (text)

**Success Response (200):**
```json
{
  "message": "Exam submitted successfully",
  "attempt": {
    "attempt_id": 19,
    "status": "submitted",
    "score": 85,
    "submitted_at": "2025-11-01T09:45:00Z"
  }
}
```

**Error Response (400):**
```json
{
  "message": "Exam already submitted"
}
```

**Mobile App Actions After Submission:**
1. Extracts score from response
2. Calls `fetchExamResults` to get questions with correct answers
3. Saves to Hive:
   - Attempt record with `recordType: 'attempt'`
   - Exam metadata with `recordType: 'exam'`
4. Marks exam as completed locally
5. Returns to dashboard

---

## Results

### 1. Fetch Exam Results
**Endpoint:** `GET /exam-attempts/{attemptId}/results`

**Headers:** Requires `Authorization: Bearer {token}`

**Success Response (200):**
```json
{
  "attempt": {
    "attempt_id": 19,
    "student_id": 38,
    "exam_assignment_id": 15,
    "status": "submitted",
    "score": 85,
    "started_at": "2025-11-01T08:15:00Z",
    "submitted_at": "2025-11-01T09:45:00Z",
    "duration_taken": 5400
  },
  "questions": [
    {
      "id": "item_6",
      "itemId": 6,
      "sectionId": 1,
      "sectionTitle": "Multiple Choice",
      "type": "mcq",
      "question": "What is 2 + 2?",
      "choices": [
        {"key": "A", "text": "3"},
        {"key": "B", "text": "4"},
        {"key": "C", "text": "5"}
      ],
      "correct": "B",
      "marks": 1
    },
    {
      "id": "item_7",
      "itemId": 7,
      "type": "true_false",
      "question": "The Earth is flat.",
      "choices": [
        {"key": "True", "text": "True"},
        {"key": "False", "text": "False"}
      ],
      "correct": "False",
      "marks": 1
    }
  ],
  "answers": {
    "item_6": "B",
    "item_7": "False",
    "item_8": "Alexander Graham Bell",
    "item_9": "A,C,D",
    "item_10": "Photosynthesis is..."
  }
}
```

**Error Response (400):**
```json
{
  "message": "Results not yet released"
}
```

**Error Response (404):**
```json
{
  "message": "Exam attempt not found"
}
```

**Mobile App Usage:**
- Compares `answers[questionId]` with `question.correct` to determine correctness
- Calculates statistics: correct count, incorrect count, unanswered count
- Displays pie chart with results
- Shows individual question review with correct/incorrect indicators
- Supports filtering by: all, correct, incorrect

---

## Data Structures

### Hive Storage Keys

**Exam Metadata:**
- **Key:** `meta_{examId}_{studentId}`
- **recordType:** `'exam'`
- **Fields:** id, studentId, subject, title, submitted, available, completed, score, studentAnswers, questions, resultsReleased, synced, completedAt

**Exam Attempt:**
- **Key:** `attempt_{examId}_{studentId}`
- **recordType:** `'attempt'`
- **Fields:** attemptId, examId, studentId, subject, answers, flaggedQuestions, submitted, completed, flagged, synced, score, completedAt, questions

**Authentication:**
- **Key:** `auth_token`
- **Value:** Bearer token string

**User Data:**
- **Key:** `current_user`
- **Value:** User object from login response

---

### Question Types Reference

| Server Type | Mobile Type | Answer Format | UI Component |
|------------|-------------|---------------|--------------|
| `mcq` | `mcq` | `"A"` or `"A,B,C"` | CheckboxListTile (multiple) |
| `torf` | `true_false` | `"True"` or `"False"` | RadioListTile |
| `iden` | `identification` | `"Text answer"` | TextFormField |
| `enum` | `enumeration` | `"Item 1, Item 2"` | TextFormField (multiline) |
| `enum_ordered` | `enumeration` | `"Item 1, Item 2"` | TextFormField (multiline) + order warning |
| `enum_unordered` | `enumeration` | `"Item 1, Item 2"` | TextFormField (multiline) |
| `essay` | `essay` | `"Long text..."` | TextFormField (multiline) |

---

### Important Notes

1. **ID Types:**
   - `exam_id` / `examId`: Numeric exam identifier
   - `assignment_id`: Links exam to class assignment
   - `attempt_id`: Unique identifier for each exam attempt
   - `student_id`: Database primary key (NOT `id_number`)

2. **Answer Submission:**
   - Always use `item_id` from questions
   - MCQ multiple selections: join with commas (no spaces)
   - True/False: capitalize first letter
   - All answers sent as strings

3. **Offline Support:**
   - Exam progress saved to Hive every answer change
   - Can resume interrupted exams
   - Results cached in Hive for offline viewing
   - Sync status tracked per exam

4. **Security:**
   - All authenticated requests require Bearer token
   - Token stored securely in Hive
   - Password verification for sensitive exams
   - Exam access controlled by schedule and status

5. **Error Handling:**
   - 10-second timeout on all API calls
   - Fallback to Hive cache on failure
   - User-friendly error messages
   - Automatic retry not implemented (manual refresh required)

---

## API Endpoints Summary

| Endpoint | Method | Purpose | Auth Required |
|----------|--------|---------|---------------|
| `/login` | POST | Student authentication | No |
| `/user` | GET | Get current user info | Yes |
| `/logout` | POST | Revoke token | Yes |
| `/exams` | GET | List assigned exams | Yes |
| `/exams/{id}` | GET | Get exam questions | Yes |
| `/exams/{id}/verify-otp` | POST | Verify exam password | Yes |
| `/exam-attempts` | POST | Start/resume attempt | Yes |
| `/exam-attempts/{id}/submit` | POST | Submit answers | Yes |
| `/exam-attempts/{id}/results` | GET | Get results | Yes |

---

## Version Information

**Mobile App Version:** 1.0.0  
**API Version:** v1  
**Last Updated:** November 2, 2025

---

## Contact & Support

For API-related issues or questions, please contact the backend development team.
