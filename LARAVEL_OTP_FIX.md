# Laravel OTP Endpoint Fix

## Problem

The mobile app expects the OTP verification endpoint to return the `attempt_id`, but it's only returning `verified: true/false`.

## Current Mobile App Expectation

When calling `POST /exams/{examId}/verify-otp`, the mobile app expects:

```json
{
  "verified": true,
  "message": "OTP verified successfully",
  "attempt": {
    "attempt_id": 123,
    "start_time": "2025-11-02 10:30:00",
    "exam_assignment_id": 15,
    "student_id": 38,
    "status": "in_progress"
  }
}
```

## Current Laravel Response (Broken)

Your Laravel endpoint probably returns:

```json
{
  "verified": true
}
```

This means `result['attempt']` is `null` in the mobile app, so `attemptId` never gets set!

## Fix Your Laravel OTP Endpoint

Update your OTP verification controller method:

```php
public function verifyOTP(Request $request, $examId)
{
    $request->validate([
        'studentId' => 'required|integer',
        'otp' => 'required|string',
    ]);

    $studentId = $request->input('studentId');
    $otp = $request->input('otp');

    // Find the exam assignment for this student and exam
    $examAssignment = ExamAssignment::where('exam_id', $examId)
        ->where('student_id', $studentId)
        ->first();

    if (!$examAssignment) {
        return response()->json([
            'verified' => false,
            'message' => 'Exam not assigned to this student',
        ], 403);
    }

    // Verify the OTP/password
    if ($examAssignment->password !== $otp) {
        return response()->json([
            'verified' => false,
            'message' => 'Invalid password',
        ], 401);
    }

    // Check if exam is still available
    if (!$this->isExamAvailable($examAssignment)) {
        return response()->json([
            'verified' => false,
            'message' => 'Exam is no longer available',
        ], 403);
    }

    // ✅ CREATE OR FIND THE ATTEMPT
    $attempt = ExamAttempt::where('exam_assignment_id', $examAssignment->exam_assignment_id)
        ->where('student_id', $studentId)
        ->whereIn('status', ['in_progress', 'paused'])
        ->first();

    if (!$attempt) {
        // Create new attempt
        $attempt = ExamAttempt::create([
            'exam_assignment_id' => $examAssignment->exam_assignment_id,
            'student_id' => $studentId,
            'status' => 'in_progress',
            'start_time' => now(),
            'score' => 0,
        ]);
    }

    // ✅ RETURN THE ATTEMPT IN THE RESPONSE
    return response()->json([
        'verified' => true,
        'message' => 'OTP verified successfully',
        'attempt' => [
            'attempt_id' => $attempt->attempt_id,
            'start_time' => $attempt->start_time,
            'exam_assignment_id' => $attempt->exam_assignment_id,
            'student_id' => $attempt->student_id,
            'status' => $attempt->status,
        ],
    ]);
}

private function isExamAvailable($examAssignment)
{
    $now = now();
    
    // Check if exam has started
    if ($examAssignment->start_time && $now->lt($examAssignment->start_time)) {
        return false;
    }
    
    // Check if exam has ended
    if ($examAssignment->end_time && $now->gt($examAssignment->end_time)) {
        return false;
    }
    
    return true;
}
```

## Alternative: Two Separate Endpoints

If you prefer to keep OTP verification separate from attempt creation, you can:

1. **Keep OTP verification simple** - just return `verified: true`
2. **Call `startExamAttempt` after OTP** - the mobile app already has this function

In `exam_screen.dart`, modify the flow (around line 685):

```dart
// After OTP is verified
if (verified) {
  // Start the exam attempt
  final result = await ApiService.startExamAttempt(
    examAssignmentId: examAssignmentId, // You'll need to get this
  );
  
  if (result != null && result['attempt'] != null) {
    attemptId = result['attempt']['attempt_id'];
    attemptStartTime = DateTime.parse(result['attempt']['start_time']);
    saveLocalData();
  }
}
```

## Testing

After implementing the fix, test the flow:

1. Start the Flutter app
2. Enter OTP for an exam
3. Check the debug logs for:
   ```
   ✅ Attempt started:
      Attempt ID: 123
      Start time: 2025-11-02 10:30:00
   ```

4. Check Hive cache has the attempt_id:
   ```
   🔍 LOADING EXAM RESULTS FROM HIVE
      ...
      Attempt ID: 123  ← Should match database
   ```

5. Try to view results - the API should now work with correct attempt_id

## Verify Database

After OTP verification, check your database:

```sql
SELECT 
    attempt_id,
    exam_assignment_id,
    student_id,
    status,
    start_time
FROM exam_attempts
WHERE student_id = 38
ORDER BY start_time DESC
LIMIT 5;
```

Make sure the `attempt_id` matches what's stored in Hive and what the mobile app is using!
