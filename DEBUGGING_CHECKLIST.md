# Results API Debugging Checklist

## Step 1: Verify the Attempt ID in Database

Run this SQL query to check if the attempt exists:

```sql
SELECT 
    attempt_id,
    student_id, 
    exam_assignment_id,
    status,
    score,
    start_time,
    end_time
FROM exam_attempts 
WHERE attempt_id = 1;
```

**Expected:** Should return a row with `student_id = 38` and `status = 'submitted'`

---

## Step 2: Check the Route Registration

In your Laravel project, run:

```bash
php artisan route:list | grep results
```

**Expected output:**
```
GET|HEAD  api/exam-attempts/{attemptId}/results .... ExamAttemptController@getResults
```

If you don't see this, add to `routes/api.php`:

```php
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/exam-attempts/{attemptId}/results', [ExamAttemptController::class, 'getResults']);
});
```

---

## Step 3: Test the Endpoint Directly

Get your auth token from the mobile app (check the debug logs when logging in), then:

```bash
curl -H "Authorization: Bearer YOUR_TOKEN_HERE" \
     http://127.0.0.1:8000/api/exam-attempts/1/results
```

### Possible Responses:

**✅ Success (200):**
```json
{
  "attempt": {...},
  "questions": [...],
  "answers": {...}
}
```

**❌ Route not found (404 HTML):**
```html
<!DOCTYPE html>
<html>
...
```
→ **Fix:** Route not registered, add to `routes/api.php`

**❌ Unauthorized (401):**
```json
{
  "message": "Unauthenticated."
}
```
→ **Fix:** Token is invalid or expired

**❌ Permission denied (403):**
```json
{
  "message": "You do not have permission to view these results"
}
```
→ **Fix:** The `attempt_id` doesn't belong to this `student_id`

**❌ Not found (404 JSON):**
```json
{
  "message": "Exam attempt not found"
}
```
→ **Fix:** Attempt ID 1 doesn't exist in database

**❌ Results not released (400):**
```json
{
  "message": "Results not yet released"
}
```
→ **Fix:** Attempt status is not 'submitted'

**❌ Internal server error (500):**
```json
{
  "message": "An error occurred while fetching results"
}
```
→ **Fix:** Check Laravel logs for the actual error

---

## Step 4: Check Mobile App Logs

After running the app, look for these debug lines:

```
🔍 LOADING EXAM RESULTS FROM API
   Exam ID: 3
   Student ID: 38
   ...
   Attempt ID from cache: 1
📡 Fetching results from API for attempt: 1
🌐 GET http://127.0.0.1:8000/api/exam-attempts/1/results
   Attempt ID: 1
📥 Response status: ???
   Content-Type: ???
```

### Diagnosis by Status Code:

- **200** → Success! Check if `Questions: 0` or has data
- **401** → Token expired, re-login
- **403** → Attempt doesn't belong to student
- **404** → Route not found (HTML) or attempt doesn't exist (JSON)
- **500** → Server error, check Laravel logs

---

## Step 5: Verify Attempt ID Match

The mobile app is using the `attempt_id` from when the exam started.

**Check what was saved to Hive:**

In `exam_screen.dart`, when the exam starts (around line 595):
```dart
attemptId = result['attempt']['attempt_id'];
```

This comes from the OTP verification response: `POST /exams/{examId}/verify-otp`

**Verify the OTP response includes the correct attempt_id:**

Check your Laravel endpoint that handles OTP verification. It should return:
```json
{
  "message": "OTP verified successfully",
  "attempt": {
    "attempt_id": 123,    // ← This must match the ID in exam_attempts table
    "start_time": "..."
  }
}
```

---

## Step 6: Check Relationships in Laravel

Your `getResults()` method uses:
```php
$attempt = ExamAttempt::with([
    'examAssignment.exam.sections.items',
    'answers'
])->find($attemptId);
```

**Verify these relationships exist in your models:**

### ExamAttempt.php
```php
public function examAssignment()
{
    return $this->belongsTo(ExamAssignment::class, 'exam_assignment_id');
}

public function answers()
{
    return $this->hasMany(ExamAnswer::class, 'attempt_id', 'attempt_id');
}
```

### ExamAssignment.php
```php
public function exam()
{
    return $this->belongsTo(Exam::class, 'exam_id');
}
```

### Exam.php
```php
public function sections()
{
    return $this->hasMany(ExamSection::class, 'exam_id');
}
```

### ExamSection.php
```php
public function items()
{
    return $this->hasMany(ExamItem::class, 'section_id');
}
```

---

## Step 7: Check Foreign Key Columns

Verify your database has the correct foreign key columns:

```sql
-- Check exam_attempts table
DESCRIBE exam_attempts;
-- Should have: attempt_id, student_id, exam_assignment_id

-- Check exam_assignments table
DESCRIBE exam_assignments;
-- Should have: exam_assignment_id, exam_id

-- Check exams table
DESCRIBE exams;
-- Should have: exam_id

-- Check exam_sections table
DESCRIBE exam_sections;
-- Should have: section_id, exam_id

-- Check exam_items table
DESCRIBE exam_items;
-- Should have: item_id, section_id

-- Check exam_answers table
DESCRIBE exam_answers;
-- Should have: answer_id, attempt_id, item_id, answer_text
```

---

## Common Issues & Solutions

### Issue: "SyntaxError: Unexpected token '<'"
**Cause:** Laravel returning HTML (404 page) instead of JSON  
**Diagnosis:** Route not registered  
**Solution:** Add route to `routes/api.php`

### Issue: "Exam attempt not found"
**Cause:** Attempt ID doesn't exist in database  
**Diagnosis:** Check database for that attempt_id  
**Solution:** Verify OTP endpoint returns correct attempt_id

### Issue: "You do not have permission"
**Cause:** Attempt belongs to different student  
**Diagnosis:** Check `attempt.student_id` vs logged-in user ID  
**Solution:** Verify authentication and attempt ownership

### Issue: Empty questions array
**Cause:** Relationships not loading or data missing  
**Diagnosis:** Check Laravel logs, verify data exists  
**Solution:** Verify relationships and add debug logging

### Issue: Wrong attempt_id sent
**Cause:** Hive cache has wrong ID or exam wasn't started properly  
**Diagnosis:** Check debug logs for "Attempt ID from cache"  
**Solution:** Clear Hive cache and retake exam

---

## Quick Test

1. Hot reload the Flutter app
2. Try to view results for exam ID 3
3. Copy the debug output showing:
   - The attempt ID being used
   - The exact URL
   - The response status code
   - Any error messages

This will tell us exactly where the problem is!
