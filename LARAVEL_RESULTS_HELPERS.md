# Laravel Backend - Missing Helper Methods

Add these helper methods to your `ExamAttemptController` or the controller handling the results endpoint:

```php
/**
 * Map server question type to mobile app type
 */
private function mapToMobileType($serverType)
{
    $mapping = [
        'mcq' => 'mcq',
        'torf' => 'true_false',
        'iden' => 'identification',
        'enum' => 'enumeration',
        'enum_ordered' => 'enumeration',
        'enum_unordered' => 'enumeration',
        'essay' => 'essay',
    ];

    return $mapping[strtolower($serverType)] ?? $serverType;
}

/**
 * Format choices for MCQ and True/False questions
 */
private function formatChoices($item)
{
    // Only MCQ and True/False have choices
    if (!in_array($item->item_type, ['mcq', 'torf'])) {
        return null;
    }

    $choices = [];
    
    // If options is stored as JSON string, decode it
    $options = is_string($item->options) 
        ? json_decode($item->options, true) 
        : $item->options;

    if (!$options) {
        return null;
    }

    // If options is an array (not associative), generate keys A, B, C, D...
    if (array_keys($options) === range(0, count($options) - 1)) {
        $key = 'A';
        foreach ($options as $text) {
            $choices[] = [
                'key' => $key,
                'text' => $text,
            ];
            $key++;
        }
    } else {
        // Options is associative array with keys
        foreach ($options as $key => $text) {
            // Convert numeric keys to letters (0->A, 1->B, etc.)
            if (is_numeric($key)) {
                $key = chr(65 + intval($key)); // 65 is ASCII for 'A'
            }
            
            $choices[] = [
                'key' => (string) $key,
                'text' => (string) $text,
            ];
        }
    }

    return $choices;
}
```

---

## Debugging Steps

1. **Test the endpoint directly:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://127.0.0.1:8000/api/exam-attempts/1/results
```

2. **Check Laravel logs:**
```bash
tail -f storage/logs/laravel.log
```

3. **Verify route is registered:**
```bash
php artisan route:list | grep results
```

4. **Check if attempt exists:**
```sql
SELECT * FROM exam_attempts WHERE attempt_id = 1;
```

---

## Common Issues

### Issue 1: 404 Not Found (HTML response)
**Cause:** Route not registered or middleware issue  
**Solution:** Add route to `routes/api.php` with correct middleware

### Issue 2: 500 Internal Server Error
**Cause:** Missing relationships or helper methods  
**Solution:** Add the helper methods above and verify relationships exist:
```php
// In ExamAttempt model
public function examAssignment()
{
    return $this->belongsTo(ExamAssignment::class, 'exam_assignment_id');
}

public function answers()
{
    return $this->hasMany(ExamAnswer::class, 'attempt_id');
}

// In ExamAssignment model
public function exam()
{
    return $this->belongsTo(Exam::class, 'exam_id');
}

// In Exam model
public function sections()
{
    return $this->hasMany(ExamSection::class, 'exam_id');
}

// In ExamSection model
public function items()
{
    return $this->hasMany(ExamItem::class, 'section_id');
}
```

### Issue 3: Empty questions array
**Cause:** Section or item relationships not loading  
**Solution:** Verify eager loading works and data exists in database

### Issue 4: Incorrect answer format
**Cause:** `answer_text` column name might be different  
**Solution:** Check your `exam_answers` table column name (might be `answer`, `student_answer`, etc.)

---

## Expected Response Format

When working correctly, the endpoint should return:

```json
{
  "attempt": {
    "attempt_id": 1,
    "student_id": 38,
    "exam_assignment_id": 15,
    "status": "submitted",
    "score": 85.5,
    "started_at": "2025-11-01 08:15:00",
    "submitted_at": "2025-11-01 09:45:00",
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
        {"key": "C", "text": "5"}
      ],
      "correct": "B",
      "marks": 1,
      "order": 1
    }
  ],
  "answers": {
    "item_6": "B",
    "item_7": "False",
    "item_8": "Alexander Graham Bell"
  }
}
```

---

## Testing from Mobile App

After implementing the fixes, test from the mobile app:

1. Clear Hive cache (or retake exam to get fresh data with questions)
2. View exam results
3. Check debug logs for:
   - `📡 Fetching results from API for attempt: X`
   - `✅ API returned results data`
   - `Questions: X` (should be > 0)
   - `Student Answers: X` (should match questions)

If still seeing HTML error, the route isn't registered correctly in Laravel.
