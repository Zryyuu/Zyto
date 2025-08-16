# Firestore Security Rules Documentation

## Overview
These security rules ensure that your Flutter app's data is properly protected in Firestore. Each user can only access their own data, and all operations require proper authentication.

## Rule Structure

### 1. User Authentication
- **Requirement**: All operations require `request.auth != null`
- **User Isolation**: Users can only access documents where `userId` matches their `request.auth.uid`

### 2. Data Collections

#### Users Collection (`/users/{userId}`)
- Users can only read/write their own user document
- Contains user profile information (uid, name, email)

#### Subcollections (User-specific data):

**Todos** (`/users/{userId}/todos/{todoId}`)
- Personal todo items and subtasks
- Required fields: `task`, `isCompleted`, `createdAt`, `userId`

**Transactions** (`/users/{userId}/transactions/{transactionId}`)
- Budget transactions (income/expense)
- Required fields: `title`, `amount`, `category`, `date`, `isIncome`, `userId`
- Validation: `amount` must be positive number

**Savings Plans** (`/users/{userId}/savings_plans/{planId}`)
- Personal savings goals
- Required fields: `name`, `targetAmount`, `currentAmount`, `targetDate`, `userId`
- Validation: `targetAmount` > 0, `currentAmount` >= 0

**Savings Transactions** (`/users/{userId}/savings_transactions/{savingsTransactionId}`)
- Transactions related to savings plans
- Required fields: `planId`, `amount`, `date`, `userId`
- Validation: `amount` must be positive number

### 3. Security Features

#### Authentication Checks
```javascript
function isAuthenticated() {
  return request.auth != null;
}

function isOwner(userId) {
  return request.auth.uid == userId;
}
```

#### Data Validation Functions
- `isValidUserData()`: Validates user profile data
- `isValidTodoData()`: Validates todo item structure
- `isValidTransactionData()`: Validates transaction data and amount
- `isValidSavingsPlanData()`: Validates savings plan data
- `isValidSavingsTransactionData()`: Validates savings transaction data

#### Access Control
- **Read**: Users can only read their own data
- **Write**: Users can only create/update documents with their own `userId`
- **Delete**: Users can only delete their own documents
- **Deny All**: Any access not explicitly allowed is denied

### 4. Key Security Benefits

1. **User Isolation**: Complete separation of user data
2. **Authentication Required**: No anonymous access allowed
3. **Data Integrity**: Field validation prevents invalid data
4. **Ownership Verification**: Double-check on userId in data
5. **Principle of Least Privilege**: Only necessary permissions granted

### 5. Deployment

To deploy these rules to Firebase:

1. **Firebase CLI Method**:
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Firebase Console Method**:
   - Go to Firebase Console > Firestore Database > Rules
   - Copy the contents of `firestore.rules`
   - Click "Publish"

### 6. Testing Rules

You can test these rules in the Firebase Console:
- Go to Firestore Database > Rules > Simulator
- Test different scenarios with authenticated/unauthenticated users
- Verify users cannot access other users' data

### 7. Rule Validation

The rules validate:
- ✅ User must be authenticated
- ✅ User can only access their own data
- ✅ Required fields are present
- ✅ Data types are correct (numbers, strings, etc.)
- ✅ Business logic (positive amounts, valid dates)
- ❌ Cross-user data access is blocked
- ❌ Anonymous access is blocked
- ❌ Invalid data structure is rejected
