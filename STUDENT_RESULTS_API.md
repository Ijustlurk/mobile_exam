# Student Results API Documentation

## Endpoint: `/api/results`

### Method: `GET`

### Description:
Fetches the results of a specific exam for a student, including their answers, the correct answers, and statistics such as the number of correct, incorrect, and unanswered questions.

### Request Parameters:
| Parameter      | Type   | Required | Description                          |
|----------------|--------|----------|--------------------------------------|
| `examId`       | String | Yes      | The unique identifier of the exam.   |
| `studentId`    | String | Yes      | The unique identifier of the student.|

### Example Request:
```http
GET /api/results?examId=12345&studentId=67890 HTTP/1.1
Host: example.com
Authorization: Bearer <token>
```

### Response:
| Field              | Type              | Description                                      |
|--------------------|-------------------|--------------------------------------------------|
| `examId`           | String            | The unique identifier of the exam.              |
| `studentId`        | String            | The unique identifier of the student.           |
| `questions`        | Array of Objects  | List of questions in the exam.                  |
| `questions[].id`   | String            | Unique identifier for the question.             |
| `questions[].question` | String         | The text of the question.                       |
| `questions[].correct`  | String         | The correct answer for the question.            |
| `questions[].studentAnswer` | String   | The student's answer to the question.           |
| `statistics`       | Object            | Summary of the student's performance.           |
| `statistics.correctCount` | Integer    | Number of questions answered correctly.         |
| `statistics.incorrectCount` | Integer  | Number of questions answered incorrectly.       |
| `statistics.unansweredCount` | Integer | Number of questions left unanswered.            |
| `statistics.scorePercent` | Integer    | Percentage score of the student.                |
| `statistics.passed` | Boolean          | Whether the student passed the exam (>= 75%).   |

### Example Response:
```json
{
  "examId": "12345",
  "studentId": "67890",
  "questions": [
    {
      "id": "q1",
      "question": "What is 2 + 2?",
      "correct": "4",
      "studentAnswer": "4"
    },
    {
      "id": "q2",
      "question": "What is the capital of France?",
      "correct": "Paris",
      "studentAnswer": "London"
    },
    {
      "id": "q3",
      "question": "True or False: The sky is blue.",
      "correct": "True",
      "studentAnswer": ""
    }
  ],
  "statistics": {
    "correctCount": 1,
    "incorrectCount": 1,
    "unansweredCount": 1,
    "scorePercent": 33,
    "passed": false
  }
}
```

### Notes:
- The `Authorization` header is required to authenticate the request.
- The `questions` array includes all questions in the exam, along with the correct answers and the student's answers.
- The `statistics` object provides a summary of the student's performance, including whether they passed the exam.

### Error Responses:
| Status Code | Message                  | Description                                      |
|-------------|--------------------------|--------------------------------------------------|
| `400`       | `Invalid Parameters`    | Missing or invalid `examId` or `studentId`.     |
| `401`       | `Unauthorized`          | Invalid or missing authentication token.        |
| `404`       | `Exam Not Found`        | No exam found for the given `examId`.           |
| `500`       | `Internal Server Error` | An unexpected error occurred on the server.     |