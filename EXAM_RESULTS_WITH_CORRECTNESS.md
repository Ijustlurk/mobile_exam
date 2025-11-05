# Exam Results API - With Correctness Data

## Updated Response Structure

The API should return the correctness evaluation already computed on the backend, so the mobile app doesn't need to manually check answers.

---

## Success Response (200 OK)

```json
{
  "attempt": {
    "attempt_id": 21,
    "student_id": 38,
    "exam_assignment_id": 15,
    "status": "submitted",
    "score": 75.5,
    "total_marks": 100,
    "started_at": "2025-11-02T08:15:00Z",
    "submitted_at": "2025-11-02T09:45:00Z",
    "duration_taken": 5400
  },
  "results": [
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
      "correctAnswer": "B",
      "studentAnswer": "B",
      "isCorrect": true,
      "pointsAwarded": 1.0,
      "maxPoints": 1.0,
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
      "correctAnswer": "False",
      "studentAnswer": "True",
      "isCorrect": false,
      "pointsAwarded": 0.0,
      "maxPoints": 1.0,
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
      "correctAnswer": "Alexander Graham Bell",
      "studentAnswer": "Graham Bell",
      "isCorrect": false,
      "pointsAwarded": 0.0,
      "maxPoints": 2.0,
      "order": 1
    },
    {
      "id": "item_9",
      "itemId": 9,
      "sectionId": 3,
      "sectionTitle": "Essay",
      "type": "essay",
      "originalType": "essay",
      "question": "Explain the importance of Object-Oriented Programming.",
      "choices": null,
      "correctAnswer": null,
      "studentAnswer": "OOP provides encapsulation, inheritance, and polymorphism...",
      "isCorrect": null,
      "pointsAwarded": 8.5,
      "maxPoints": 10.0,
      "feedback": "Good explanation but missing some key concepts.",
      "order": 1
    }
  ],
  "statistics": {
    "totalQuestions": 4,
    "correctAnswers": 1,
    "incorrectAnswers": 2,
    "unanswered": 0,
    "manuallyGraded": 1,
    "totalPointsAwarded": 9.5,
    "totalPointsPossible": 14.0,
    "percentageScore": 67.86
  }
}
```

---

## Field Descriptions

### `results` array (replaces `questions` + `answers` objects):

Each item contains:

- **`id`** (string): Frontend identifier, format `"item_{itemId}"`
- **`itemId`** (integer): Database item ID
- **`sectionId`** (integer): Section this question belongs to
- **`sectionTitle`** (string): Section name
- **`directions`** (string, optional): Section-level instructions
- **`type`** (string): Mobile app question type (`mcq`, `true_false`, `identification`, `enumeration`, `essay`)
- **`originalType`** (string): Database question type (`mcq`, `torf`, `iden`, `enum`, `essay`)
- **`question`** (string): The question text
- **`choices`** (array of objects, nullable): Answer options for MCQ/True-False
  - `key` (string): Option identifier (A, B, C, D, or True/False)
  - `text` (string): Option text
- **`correctAnswer`** (string, nullable): The correct answer
  - For MCQ/TORF: The key (e.g., "B", "False")
  - For Identification/Enumeration: The expected text
  - For Essay: `null` (manually graded)
- **`studentAnswer`** (string, nullable): What the student submitted
  - Same format as `correctAnswer`
  - `null` if unanswered
- **`isCorrect`** (boolean, nullable): Whether the answer is correct
  - `true`: Correct
  - `false`: Incorrect
  - `null`: Manually graded (essay) or unanswered
- **`pointsAwarded`** (number): Points the student received (0.0 if incorrect)
- **`maxPoints`** (number): Maximum points possible for this question
- **`feedback`** (string, optional): Teacher's feedback (for manually graded questions)
- **`order`** (integer): Display order within section

### `statistics` object:

Summary of performance:

- **`totalQuestions`**: Total number of questions
- **`correctAnswers`**: Count of automatically correct answers
- **`incorrectAnswers`**: Count of incorrect answers
- **`unanswered`**: Count of questions not answered
- **`manuallyGraded`**: Count of questions requiring manual grading
- **`totalPointsAwarded`**: Total points the student earned
- **`totalPointsPossible`**: Maximum points available
- **`percentageScore`**: Score as percentage

---

## Laravel Backend Update

Update your `getResults()` method to return this structure:

```php
public function getResults(Request $request, $attemptId)
{
    try {
        $studentId = $request->user()->id;

        $attempt = ExamAttempt::with([
            'examAssignment.exam.sections.items',
            'answers'
        ])->find($attemptId);

        if (!$attempt) {
            return response()->json(['message' => 'Exam attempt not found'], 404);
        }

        if ($attempt->student_id !== $studentId) {
            return response()->json(['message' => 'You do not have permission to view these results'], 403);
        }

        if ($attempt->status !== 'submitted') {
            return response()->json(['message' => 'Results not yet released'], 400);
        }

        $exam = $attempt->examAssignment->exam;
        
        // Create a map of student answers for quick lookup
        $studentAnswersMap = [];
        foreach ($attempt->answers as $answer) {
            $studentAnswersMap[$answer->item_id] = $answer;
        }

        // Build results array with correctness data
        $results = [];
        $totalCorrect = 0;
        $totalIncorrect = 0;
        $totalUnanswered = 0;
        $manuallyGraded = 0;
        $totalPointsAwarded = 0;
        $totalPointsPossible = 0;

        foreach ($exam->sections as $section) {
            foreach ($section->items as $item) {
                $mobileType = $this->mapToMobileType($item->item_type);
                $studentAnswer = $studentAnswersMap[$item->item_id] ?? null;
                
                // Determine correctness
                $isCorrect = null;
                $pointsAwarded = 0;
                
                if ($item->item_type === 'essay') {
                    // Essay - manually graded
                    $isCorrect = null;
                    $pointsAwarded = $studentAnswer ? ($studentAnswer->points_awarded ?? 0) : 0;
                    $manuallyGraded++;
                } elseif (!$studentAnswer || empty($studentAnswer->answer_text)) {
                    // Unanswered
                    $isCorrect = false;
                    $pointsAwarded = 0;
                    $totalUnanswered++;
                } else {
                    // Auto-graded questions
                    $isCorrect = $this->checkAnswer(
                        $item->expected_answer,
                        $studentAnswer->answer_text,
                        $item->item_type
                    );
                    
                    $pointsAwarded = $isCorrect ? $item->points_awarded : 0;
                    
                    if ($isCorrect) {
                        $totalCorrect++;
                    } else {
                        $totalIncorrect++;
                    }
                }
                
                $totalPointsAwarded += $pointsAwarded;
                $totalPointsPossible += $item->points_awarded;
                
                $resultItem = [
                    'id' => 'item_' . $item->item_id,
                    'itemId' => $item->item_id,
                    'sectionId' => $section->section_id,
                    'sectionTitle' => $section->section_title,
                    'type' => $mobileType,
                    'originalType' => $item->item_type,
                    'question' => $item->question,
                    'choices' => $this->formatChoices($item),
                    'correctAnswer' => $item->item_type === 'essay' ? null : $item->expected_answer,
                    'studentAnswer' => $studentAnswer ? $studentAnswer->answer_text : null,
                    'isCorrect' => $isCorrect,
                    'pointsAwarded' => (float) $pointsAwarded,
                    'maxPoints' => (float) $item->points_awarded,
                    'order' => $item->order ?? 0,
                ];

                // Add directions if available
                if (isset($section->directions)) {
                    $resultItem['directions'] = $section->directions;
                }

                // Add feedback if available (for manually graded)
                if ($studentAnswer && isset($studentAnswer->feedback)) {
                    $resultItem['feedback'] = $studentAnswer->feedback;
                }

                $results[] = $resultItem;
            }
        }

        return response()->json([
            'attempt' => [
                'attempt_id' => $attempt->attempt_id,
                'student_id' => $attempt->student_id,
                'exam_assignment_id' => $attempt->exam_assignment_id,
                'status' => $attempt->status,
                'score' => (float) $attempt->score,
                'total_marks' => (float) $totalPointsPossible,
                'started_at' => $attempt->start_time,
                'submitted_at' => $attempt->end_time,
                'duration_taken' => $attempt->end_time && $attempt->start_time
                    ? strtotime($attempt->end_time) - strtotime($attempt->start_time)
                    : 0,
            ],
            'results' => $results,
            'statistics' => [
                'totalQuestions' => count($results),
                'correctAnswers' => $totalCorrect,
                'incorrectAnswers' => $totalIncorrect,
                'unanswered' => $totalUnanswered,
                'manuallyGraded' => $manuallyGraded,
                'totalPointsAwarded' => (float) $totalPointsAwarded,
                'totalPointsPossible' => (float) $totalPointsPossible,
                'percentageScore' => $totalPointsPossible > 0 
                    ? round(($totalPointsAwarded / $totalPointsPossible) * 100, 2)
                    : 0,
            ],
        ]);
    } catch (\Exception $e) {
        \Log::error('Error fetching exam results: ' . $e->getMessage(), [
            'attempt_id' => $attemptId,
            'trace' => $e->getTraceAsString()
        ]);
        
        return response()->json([
            'message' => 'An error occurred while fetching results',
            'error' => config('app.debug') ? $e->getMessage() : 'Internal server error'
        ], 500);
    }
}

/**
 * Check if student answer is correct
 */
private function checkAnswer($correctAnswer, $studentAnswer, $itemType)
{
    // Normalize both answers
    $correct = trim(strtolower($correctAnswer));
    $student = trim(strtolower($studentAnswer));
    
    if ($itemType === 'mcq' || $itemType === 'torf') {
        // Exact match for MCQ and True/False
        return $correct === $student;
    } elseif ($itemType === 'iden') {
        // Case-insensitive match for identification
        return $correct === $student;
    } elseif (in_array($itemType, ['enum', 'enum_ordered', 'enum_unordered'])) {
        // For enumeration, check if all expected items are present
        $correctItems = array_map('trim', explode(',', $correct));
        $studentItems = array_map('trim', explode(',', $student));
        
        sort($correctItems);
        sort($studentItems);
        
        return $correctItems === $studentItems;
    }
    
    return false;
}
```

---

## Mobile App Update

The mobile app should:

1. **Receive** the `results` array instead of separate `questions` and `answers`
2. **Use** the `isCorrect` field directly (no manual checking)
3. **Display** `pointsAwarded` / `maxPoints` for each question
4. **Show** the `statistics` summary

No more manual answer comparison needed!
