# Exam Results API Specification

This document specifies the API contract for displaying exam results in the mobile app.

---

## Endpoint

**GET** `/exam-attempts/{attemptId}/results`

---

## Authentication

**Headers Required:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

---

## Request

**URL Parameters:**
- `attemptId` (integer, required): The unique identifier of the exam attempt

**Example Request:**
```http
GET /exam-attempts/19/results HTTP/1.1
Host: 127.0.0.1:8000
Authorization: Bearer 1|abc123...
Content-Type: application/json
Accept: application/json
```

---

## Success Response (200 OK)

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
      "correct": "B",
      "marks": 1,
      "order": 1
    },
    {
      "id": "item_7",
      "itemId": 7,
      "sectionId": 1,
      "sectionTitle": "True or False",
      "type": "true_false",
      "originalType": "torf",
      "question": "The Earth is flat.",
      "choices": [
        {"key": "True", "text": "True"},
        {"key": "False", "text": "False"}
      ],
      "correct": "False",
      "marks": 1,
      "order": 2
    },
    {
      "id": "item_8",
      "itemId": 8,
      "sectionId": 2,
      "sectionTitle": "Identification",
      "type": "identification",
      "originalType": "iden",
      "question": "Who invented the telephone?",
      "choices": null,
      "correct": "Alexander Graham Bell",
      "marks": 2,
      "order": 1
    },
    {
      "id": "item_9",
      "itemId": 9,
      "sectionId": 3,
      "sectionTitle": "Enumeration",
      "type": "enumeration",
      "originalType": "enum_ordered",
      "question": "List the steps of scientific method in order.",
      "choices": null,
      "correct": "Observation, Question, Hypothesis, Experiment, Analysis, Conclusion",
      "marks": 5,
      "order": 1
    },
    {
      "id": "item_10",
      "itemId": 10,
      "sectionId": 4,
      "sectionTitle": "Essay",
      "type": "essay",
      "originalType": "essay",
      "question": "Explain the concept of photosynthesis.",
      "choices": null,
      "correct": null,
      "marks": 10,
      "order": 1
    }
  ],
  "answers": {
    "item_6": "B",
    "item_7": "False",
    "item_8": "Alexander Graham Bell",
    "item_9": "Observation, Question, Hypothesis, Experiment, Analysis, Conclusion",
    "item_10": "Photosynthesis is the process by which green plants and some other organisms use sunlight to synthesize foods with the help of chlorophyll..."
  }
}
```

---

## Response Fields

### `attempt` Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `attempt_id` | integer | Yes | Unique identifier for the exam attempt |
| `student_id` | integer | Yes | Student's database ID |
| `exam_assignment_id` | integer | Yes | Assignment ID linking exam to class |
| `status` | string | Yes | Always "submitted" for completed exams |
| `score` | number | Yes | Student's score (0-100 or total points) |
| `started_at` | string (ISO 8601) | Yes | When the student started the exam |
| `submitted_at` | string (ISO 8601) | Yes | When the student submitted the exam |
| `duration_taken` | integer | Yes | Time taken in seconds |

### `questions` Array

Each question object contains:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Question identifier (format: "item_{itemId}") |
| `itemId` | integer | Yes | Numeric item ID from database |
| `sectionId` | integer | Yes | Section this question belongs to |
| `sectionTitle` | string | Yes | Title of the section |
| `directions` | string | No | Instructions for this section |
| `type` | string | Yes | Mobile app question type (see mapping below) |
| `originalType` | string | Yes | Server question type (preserved for UI) |
| `question` | string | Yes | The question text |
| `choices` | array/null | Conditional | Array of choice objects for MCQ/True-False, null otherwise |
| `correct` | string/null | Conditional | The correct answer(s), null for essay questions |
| `marks` | integer | Yes | Points awarded for this question |
| `order` | integer | Yes | Display order within section |

**Choice Object Structure (for MCQ/True-False):**
```json
{
  "key": "A",
  "text": "Option text"
}
```

### `answers` Object

Key-value pairs where:
- **Key:** Question ID (e.g., "item_6")
- **Value:** Student's submitted answer (string)

**Answer Formats by Question Type:**
- **MCQ (Single):** `"B"` - Single option key
- **MCQ (Multiple):** `"A,B,D"` - Comma-separated option keys (no spaces)
- **True/False:** `"True"` or `"False"` - Capitalized
- **Identification:** `"Text answer"` - Student's text response
- **Enumeration:** `"Item 1, Item 2, Item 3"` - Comma-separated items
- **Essay:** `"Long form answer..."` - Student's essay response

---

## Question Type Mapping

The mobile app converts server question types to internal types for rendering:

| Server Type (`originalType`) | Mobile Type (`type`) | Has Choices | Answer Format |
|------------------------------|---------------------|-------------|---------------|
| `mcq` | `mcq` | Yes | `"A"` or `"A,B,D"` |
| `torf` | `true_false` | Yes | `"True"` or `"False"` |
| `iden` | `identification` | No | `"Text"` |
| `enum` | `enumeration` | No | `"Item 1, Item 2"` |
| `enum_ordered` | `enumeration` | No | `"Item 1, Item 2"` |
| `enum_unordered` | `enumeration` | No | `"Item 1, Item 2"` |
| `essay` | `essay` | No | `"Long text"` |

**Important:** The `originalType` field must be preserved so the mobile app can distinguish between `enum`, `enum_ordered`, and `enum_unordered` for proper UI display.

---

## Error Responses

### 400 Bad Request - Results Not Released
```json
{
  "message": "Results not yet released"
}
```

**When:** The exam results haven't been published by the instructor yet.

### 403 Forbidden - Access Denied
```json
{
  "message": "You do not have permission to view these results"
}
```

**When:** The student is trying to access another student's results.

### 404 Not Found - Attempt Not Found
```json
{
  "message": "Exam attempt not found"
}
```

**When:** The attempt ID doesn't exist or belongs to a different student.

### 401 Unauthorized
```json
{
  "message": "Unauthenticated"
}
```

**When:** Invalid or missing authentication token.

---

## Mobile App Processing

### 1. Results Calculation

The mobile app calculates the following statistics:

```javascript
// For each question, compare student answer with correct answer
correctCount = questions.filter(q => 
  answers[q.id]?.toLowerCase().trim() === q.correct?.toLowerCase().trim()
).length

incorrectCount = questions.filter(q => 
  answers[q.id] && 
  answers[q.id]?.toLowerCase().trim() !== q.correct?.toLowerCase().trim()
).length

unansweredCount = questions.length - Object.keys(answers).length

scorePercent = (correctCount / questions.length) * 100
passed = scorePercent >= 75
```

### 2. Display Components

**Summary Card:**
- Total questions
- Correct count (green)
- Incorrect count (red)
- Unanswered count (gray)
- Score percentage
- Pass/Fail badge
- Pie chart visualization

**Question List:**
- Displays all questions with student answers
- Color-coded icons:
  - ✅ Green check - Correct
  - ❌ Red X - Incorrect
  - ⏱️ Gray clock - Unanswered
- Expandable cards showing correct answer
- Filter options: All / Correct / Incorrect

### 3. Caching

After fetching results, the mobile app caches the data in Hive storage:

**Storage Key:** `attempt_{examId}_{studentId}`

**Cached Data:**
```json
{
  "attemptId": 19,
  "examId": "3",
  "studentId": "38",
  "answers": {...},
  "questions": [...],
  "score": 85,
  "submitted": true,
  "completed": true,
  "recordType": "attempt"
}
```

This enables offline viewing of results.

---

## Example Use Cases

### Use Case 1: Perfect Score
```json
{
  "attempt": {
    "score": 100,
    ...
  },
  "questions": [
    {
      "id": "item_1",
      "correct": "A",
      ...
    }
  ],
  "answers": {
    "item_1": "A"
  }
}
```

**Result:** 100% correct, confetti animation plays, "Passed" badge shown.

### Use Case 2: Multiple Choice with Multiple Selections
```json
{
  "questions": [
    {
      "id": "item_5",
      "type": "mcq",
      "question": "Select all prime numbers:",
      "choices": [
        {"key": "A", "text": "2"},
        {"key": "B", "text": "4"},
        {"key": "C", "text": "5"},
        {"key": "D", "text": "7"}
      ],
      "correct": "A,C,D"
    }
  ],
  "answers": {
    "item_5": "A,C,D"
  }
}
```

**Result:** Marked as correct. Mobile app displays checkboxes for A, C, and D as selected.

### Use Case 3: Essay Question (No Auto-Grading)
```json
{
  "questions": [
    {
      "id": "item_10",
      "type": "essay",
      "correct": null
    }
  ],
  "answers": {
    "item_10": "Long essay response..."
  }
}
```

**Result:** Not counted in correct/incorrect stats. Displayed but not marked right/wrong.

### Use Case 4: Unanswered Question
```json
{
  "questions": [
    {
      "id": "item_3",
      ...
    }
  ],
  "answers": {
    // item_3 not present
  }
}
```

**Result:** Counted in unanswered count, gray clock icon shown.

---

## Important Notes

1. **Case Insensitivity:** The mobile app performs case-insensitive comparison for text answers (identification, enumeration).

2. **Whitespace:** Leading/trailing whitespace is trimmed before comparison.

3. **Multiple Selections:** MCQ answers with multiple selections must be comma-separated with NO spaces (e.g., `"A,B,D"` not `"A, B, D"`).

4. **True/False Capitalization:** Must be exactly `"True"` or `"False"` (capitalized).

5. **Essay Grading:** Essay questions with `correct: null` are displayed but not included in automatic correctness calculations.

6. **Question Order:** Questions are displayed in the order specified by the `order` field within each section.

7. **Missing Data:** If `questions` array is empty, the mobile app displays "No results available" with a back button.

---

## Testing Checklist

- [ ] Correct answers match exactly (case-insensitive)
- [ ] Multiple MCQ selections use comma-separated format
- [ ] True/False answers are capitalized
- [ ] Essay questions don't break statistics calculation
- [ ] Unanswered questions are handled properly
- [ ] Results display correctly offline (from cache)
- [ ] Error messages are user-friendly
- [ ] Score percentage calculates correctly
- [ ] Pass/fail threshold works (75%)
- [ ] Confetti plays for passing scores

---

**Last Updated:** November 2, 2025  
**API Version:** v1  
**Mobile App Version:** 1.0.0
