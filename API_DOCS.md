# Fendo API Documentation
> Version: 1.0.1 · Base URL: `http://localhost/fendo/public/api/v1`

---

## Table of Contents
1. [Getting Started](#getting-started)
2. [Authentication](#authentication)
3. [Standard Response Format](#standard-response-format)
4. [Error Codes](#error-codes)
5. [Step 1 — Auth APIs](#step-1--auth-apis)
6. [Step 2 — User Profile APIs](#step-2--user-profile-apis)
7. [Step 3 — Groups APIs](#step-3--groups-apis)
8. [Step 4 — Expenses APIs](#step-4--expenses-apis)
9. [Step 5 — Balances APIs](#step-5--balances-apis)
10. [Step 6 — Bills APIs](#step-6--bills-apis)
11. [Step 7 — Settlements APIs](#step-7--settlements-apis)
12. [Step 8 — Activity Feed APIs](#step-8--activity-feed-apis)
13. [Step 9 — Notifications APIs](#step-9--notifications-apis)
14. [Step 10 — Reports APIs](#step-10--reports-apis)
15. [Step 11 — Dashboard API](#step-11--dashboard-api)
16. [Categories API](#categories-api)
17. [How to Test](#how-to-test)

---

## Getting Started

### Base URL
```
http://localhost/fendo/public/api/v1
```
> For production replace with your domain: `https://api.fendo.app/v1`

### Headers (all protected requests)
| Header | Value |
|---|---|
| `Accept` | `application/json` |
| `Content-Type` | `application/json` |
| `Authorization` | `Bearer {access_token}` |

### Auth Flow
```
Register → Verify OTP → Get token → Use token in all requests
```

---

## Standard Response Format

### Success
```json
{
  "success": true,
  "message": "Human readable message",
  "data": { ... }
}
```

### Paginated List
```json
{
  "success": true,
  "message": "Success",
  "data": {
    "current_page": 1,
    "data": [ ... ],
    "per_page": 20,
    "total": 100,
    "last_page": 5,
    "next_page_url": "...",
    "prev_page_url": null
  }
}
```

### Error
```json
{
  "success": false,
  "message": "Human readable error",
  "errors": {
    "field_name": ["Validation message"]
  }
}
```

---

## Error Codes

| HTTP Code | Meaning |
|---|---|
| `200` | OK |
| `201` | Created |
| `204` | No Content |
| `400` | Bad Request |
| `401` | Unauthenticated — missing or invalid token |
| `403` | Forbidden — not authorized to do this |
| `404` | Not Found |
| `409` | Conflict (e.g. already a member) |
| `422` | Validation Error |
| `429` | Too Many Requests |
| `500` | Server Error |

---

## Step 1 — Auth APIs

### 1.1 Register
```
POST /auth/register
```
**No auth required**

**Body:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "Password1",
  "password_confirmation": "Password1",
  "phone": "+1234567890"
}
```

**Password rules:** min 8 chars, 1 uppercase, 1 number.

**Response `201`:**
```json
{
  "success": true,
  "message": "Registration successful. Please verify your email.",
  "data": {
    "user_id": 1,
    "email": "john@example.com",
    "otp": "482910",
    "message": "OTP sent to your email. Please verify to continue."
  }
}
```
> `otp` is only returned in **local/dev** environment. Remove from UI in production.

---

### 1.2 Verify OTP (Email)
```
POST /auth/verify-otp
```
**No auth required**

**Body:**
```json
{
  "email": "john@example.com",
  "otp": "482910",
  "purpose": "register"
}
```

`purpose` options: `register` | `reset_password`

**Response `200`:**
```json
{
  "success": true,
  "message": "Email verified successfully.",
  "data": {
    "user": { "id": 1, "name": "John Doe", "email": "john@example.com", ... },
    "access_token": "1|abcdef1234567890...",
    "token_type": "Bearer"
  }
}
```
> **Save the `access_token` immediately.** Use it in the `Authorization` header for all subsequent requests.

---

### 1.3 Resend OTP
```
POST /auth/resend-otp
```
**No auth required** · Rate limited: 1 resend per 60 seconds

**Body:**
```json
{
  "email": "john@example.com",
  "purpose": "register"
}
```

**Response `200`:**
```json
{
  "success": true,
  "message": "OTP resent successfully.",
  "data": { "otp": "112233" }
}
```

---

### 1.4 Login
```
POST /auth/login
```
**No auth required**

**Body:**
```json
{
  "email": "john@example.com",
  "password": "Password1",
  "device_name": "iPhone 15 Pro"
}
```

`device_name` is optional but recommended. Sending it allows multi-device sessions.

**Response `200`:**
```json
{
  "success": true,
  "message": "Login successful.",
  "data": {
    "user": { "id": 1, "name": "John Doe", "email": "...", "currency": "USD", ... },
    "access_token": "2|xyz...",
    "token_type": "Bearer"
  }
}
```

**Error `403` — email not verified:**
```json
{
  "success": false,
  "message": "Please verify your email before logging in."
}
```

---

### 1.5 Logout
```
POST /auth/logout
```
**Auth required**

**Response `200`:**
```json
{
  "success": true,
  "message": "Logged out successfully.",
  "data": null
}
```

---

### 1.6 Get Current User
```
GET /auth/me
```
**Auth required**

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+1234567890",
    "avatar": null,
    "currency": "USD",
    "timezone": "UTC",
    "language": "en",
    "venmo_handle": null,
    "paypal_email": null,
    "notification_settings": { ... }
  }
}
```

---

### 1.7 Forgot Password
```
POST /auth/forgot-password
```
**No auth required**

**Body:**
```json
{
  "email": "john@example.com"
}
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Password reset OTP sent to your email.",
  "data": { "otp": "993847" }
}
```

---

### 1.8 Reset Password
```
POST /auth/reset-password
```
**No auth required** — OTP verified inline here

**Body:**
```json
{
  "email": "john@example.com",
  "otp": "993847",
  "password": "NewPass1",
  "password_confirmation": "NewPass1"
}
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Password reset successfully. Please log in with your new password."
}
```

---

### 1.9 Social Login (Google / Apple)
```
POST /auth/social-login
```
**No auth required**

The mobile app gets the user's info from Google/Apple SDK, then sends it here.

**Body:**
```json
{
  "provider": "google",
  "provider_id": "google_uid_12345",
  "email": "john@gmail.com",
  "name": "John Doe",
  "avatar": "https://lh3.googleusercontent.com/...",
  "device_name": "Pixel 9"
}
```

`provider`: `google` | `apple`

**Response `200`:**
```json
{
  "success": true,
  "message": "Logged in via social login.",
  "data": {
    "user": { ... },
    "access_token": "3|abc...",
    "token_type": "Bearer",
    "is_new_user": false
  }
}
```

---

### 1.10 Refresh Token
```
POST /auth/refresh
```
**Auth required** — send your current Bearer token. Revokes it and issues a new one.

**Headers:**
```
Authorization: Bearer {current_token}
Accept: application/json
```

**Response `200`:**
```json
{
  "data": {
    "access_token": "4|newtoken...",
    "token_type": "Bearer"
  }
}
```

---

## Step 2 — User Profile APIs

All require `Authorization: Bearer {token}`

### 2.1 Get Profile
```
GET /user/profile
```

### 2.2 Update Profile
```
PUT /user/profile
```
**Body (all fields optional):**
```json
{
  "name": "John Updated",
  "phone": "+19876543210",
  "timezone": "America/New_York",
  "currency": "EUR",
  "language": "en",
  "venmo_handle": "@johndoe",
  "paypal_email": "john@paypal.com",
  "cashapp_tag": "$johndoe"
}
```

### 2.3 Upload Avatar
```
POST /user/avatar
Content-Type: multipart/form-data
```
**Form field:** `avatar` — image file (jpg/png/webp, max 2MB)

**Response:**
```json
{
  "data": { "avatar": "avatars/abc123.jpg" }
}
```

### 2.4 Change Password
```
PUT /user/password
```
**Body:**
```json
{
  "current_password": "OldPass1",
  "password": "NewPass2",
  "password_confirmation": "NewPass2"
}
```

### 2.5 Update FCM Token
```
PUT /user/fcm-token
```
**Body:**
```json
{
  "fcm_token": "fcm_device_token_here..."
}
```
> Call this on every app launch after login.

### 2.6 List Sessions
```
GET /user/sessions
```
**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "iPhone 15 Pro",
      "created_at": "2026-06-11T10:00:00Z",
      "last_used": "2026-06-11T14:30:00Z",
      "is_current": true
    }
  ]
}
```

### 2.7 Revoke a Session
```
DELETE /user/sessions/{id}
```

### 2.8 Notification Settings — Get
```
GET /user/notification-settings
```

### 2.9 Notification Settings — Update
```
PUT /user/notification-settings
```
**Body (all optional):**
```json
{
  "all_enabled": true,
  "expense_added": true,
  "expense_edited": true,
  "settlement_received": true,
  "settlement_requested": true,
  "bill_reminder": true,
  "bill_overdue": true,
  "group_invitation": true,
  "member_joined": false,
  "weekly_summary": false,
  "email_notifications": false,
  "quiet_hours_start": "22:00",
  "quiet_hours_end": "08:00"
}
```

### 2.10 Delete Account
```
DELETE /user/account
```
**Body:**
```json
{
  "confirmation": "DELETE MY ACCOUNT",
  "password": "YourPassword1"
}
```
> Soft-deletes and anonymizes the account (GDPR).

---

## Step 3 — Groups APIs

### 3.1 List My Groups
```
GET /groups
```

### 3.2 Create Group
```
POST /groups
```
**Body:**
```json
{
  "name": "Bali Trip 2026",
  "type": "vacation",
  "currency": "USD",
  "simplify_debts": true,
  "member_emails": ["alice@example.com", "bob@example.com"]
}
```

`type` options: `apartment` | `family` | `vacation` | `friends` | `events` | `business` | `other`

### 3.3 Get Group
```
GET /groups/{id}
```

### 3.4 Update Group
```
PUT /groups/{id}
```
**Admin only.**

### 3.5 Delete Group
```
DELETE /groups/{id}
```
**Admin only.**

### 3.6 Archive / Unarchive
```
POST /groups/{id}/archive
POST /groups/{id}/unarchive
```

### 3.7 Leave Group
```
POST /groups/{id}/leave
```
> Returns `400` if you are the only admin — assign another admin first.

### 3.8 Generate Invite Link
```
POST /groups/{id}/invite-link
```
**Admin only.**

**Response:**
```json
{
  "data": {
    "invite_token": "ABcDeFgH...",
    "invite_link": "http://yourapp/api/v1/groups/join/ABcDeFgH...",
    "expires_at": "2026-06-18T20:00:00Z"
  }
}
```

### 3.9 Invite by Email
```
POST /groups/{id}/invite
```
**Body:**
```json
{
  "emails": ["charlie@example.com", "diana@example.com"]
}
```

### 3.10 Join via Token
```
POST /groups/join/{token}
```
**Auth required.** No body needed.

### 3.11 List Members
```
GET /groups/{id}/members
```

### 3.12 Update Member Role
```
PUT /groups/{id}/members/{userId}/role
```
**Body:** `{ "role": "admin" }` — `admin` | `member`

### 3.13 Remove Member
```
DELETE /groups/{id}/members/{userId}
```

### 3.14 Group Balances
```
GET /groups/{id}/balances
```

When the group has `simplify_debts: true` (set at create/update), balances are returned using **min-cash-flow simplification** — the fewest payments needed to settle all debts. When `false`, raw pairwise ledger balances are returned.

**Response:**
```json
{
  "data": {
    "summary": {
      "you_owe": 45.00,
      "you_are_owed": 120.00,
      "net_balance": 75.00
    },
    "balances": [
      {
        "owes": { "id": 2, "name": "Alice", "avatar": null },
        "to":   { "id": 1, "name": "John",  "avatar": null },
        "amount": 45.00,
        "currency": "USD"
      }
    ],
    "simplified": true
  }
}
```

`simplified` — `true` when debt simplification was applied; `false` when raw ledger pairs are shown.

---

## Step 4 — Expenses APIs

### 4.1 List Expenses
```
GET /expenses
GET /expenses?group_id=1
GET /expenses?from=2026-06-01&to=2026-06-30
```

### 4.2 Create Expense
```
POST /expenses
```

**Equal split example:**
```json
{
  "title": "Dinner at Nobu",
  "amount": 120.00,
  "currency": "USD",
  "expense_date": "2026-06-11",
  "group_id": 1,
  "category_id": 1,
  "split_method": "equal",
  "payers": [
    { "user_id": 1, "amount_paid": 120.00 }
  ],
  "participants": [
    { "user_id": 1 },
    { "user_id": 2 },
    { "user_id": 3 }
  ]
}
```

**Percentage split example:**
```json
{
  "title": "Hotel Room",
  "amount": 300.00,
  "split_method": "percentage",
  "payers": [{ "user_id": 1, "amount_paid": 300.00 }],
  "participants": [
    { "user_id": 1, "percentage": 50 },
    { "user_id": 2, "percentage": 30 },
    { "user_id": 3, "percentage": 20 }
  ]
}
```

**Shares split example:**
```json
{
  "title": "Groceries",
  "amount": 90.00,
  "split_method": "shares",
  "payers": [{ "user_id": 1, "amount_paid": 90.00 }],
  "participants": [
    { "user_id": 1, "shares": 3 },
    { "user_id": 2, "shares": 2 },
    { "user_id": 3, "shares": 1 }
  ]
}
```

**Custom amount split:**
```json
{
  "title": "Lunch",
  "amount": 75.00,
  "split_method": "custom",
  "payers": [{ "user_id": 1, "amount_paid": 75.00 }],
  "participants": [
    { "user_id": 1, "amount": 30 },
    { "user_id": 2, "amount": 25 },
    { "user_id": 3, "amount": 20 }
  ]
}
```

**Itemized split example:**
```json
{
  "title": "Restaurant bill",
  "amount": 100.00,
  "split_method": "itemized",
  "payers": [{ "user_id": 1, "amount_paid": 100.00 }],
  "participants": [
    { "user_id": 1 },
    { "user_id": 2 },
    { "user_id": 3 }
  ],
  "items": [
    { "name": "Steak", "amount": 40.00, "assigned_to": [1] },
    { "name": "Pasta", "amount": 25.00, "assigned_to": [2] },
    { "name": "Shared drinks", "amount": 35.00, "assigned_to": [1, 2, 3] }
  ]
}
```

**Multi-payer example:**
```json
{
  "title": "Uber to Airport",
  "amount": 60.00,
  "split_method": "equal",
  "is_multi_payer": true,
  "payers": [
    { "user_id": 1, "amount_paid": 40.00 },
    { "user_id": 2, "amount_paid": 20.00 }
  ],
  "participants": [{ "user_id": 1 }, { "user_id": 2 }, { "user_id": 3 }]
}
```

### 4.3 Get Expense
```
GET /expenses/{id}
```

### 4.4 Update Expense
```
PUT /expenses/{id}
```
Only creator can update. **Body (partial):**
```json
{
  "title": "Updated Title",
  "category_id": 2,
  "merchant_name": "Nobu Restaurant"
}
```

### 4.5 Delete Expense
```
DELETE /expenses/{id}
```
Only creator can delete. Automatically reverses ledger entries.

### 4.6 Group Expenses
```
GET /groups/{id}/expenses
```

### 4.7 Scan Receipt (OCR)
```
POST /expenses/scan-receipt
Content-Type: multipart/form-data
```
**Form field:** `receipt` — image file (jpg/png/webp, max 5MB)

> Currently returns stub. Integrate Google Cloud Vision or AWS Textract.

---

## Step 5 — Balances APIs

### 5.1 My Overall Balances
```
GET /balances
```
**Response:**
```json
{
  "data": {
    "total_you_owe": 85.50,
    "total_you_are_owed": 210.00,
    "net_balance": 124.50,
    "you_owe": [
      { "user": { "id": 2, "name": "Alice" }, "group": { "id": 1, "name": "Bali Trip" }, "amount": 45.00, "currency": "USD" }
    ],
    "you_are_owed": [
      { "user": { "id": 3, "name": "Bob" }, "group": { "id": 1, "name": "Bali Trip" }, "amount": 120.00, "currency": "USD" }
    ]
  }
}
```

### 5.2 Balance Breakdown (per person)
```
GET /balances/breakdown
```
Returns net balance per person (positive = they owe you, negative = you owe them).

---

## Step 6 — Bills APIs

### 6.1 List Bills
```
GET /bills
GET /bills?status=upcoming
```
`status` filter: `upcoming` | `due_today` | `overdue` | `paid` | `partial`

### 6.2 Create Bill
```
POST /bills
```
**One-time bill:**
```json
{
  "name": "Electricity April",
  "amount": 150.00,
  "due_date": "2026-06-20",
  "group_id": 1,
  "notes": "Split equally",
  "reminder_days": [1, 3, 7],
  "splits": [
    { "user_id": 1, "amount_owed": 50.00 },
    { "user_id": 2, "amount_owed": 50.00 },
    { "user_id": 3, "amount_owed": 50.00 }
  ]
}
```

**Recurring bill:**
```json
{
  "name": "Netflix",
  "amount": 22.00,
  "due_date": "2026-06-20",
  "bill_type": "recurring",
  "frequency": "monthly",
  "recurrence_end_date": "2026-12-31"
}
```

`frequency` options: `weekly` | `biweekly` | `monthly` | `quarterly` | `annually`

### 6.3 Get / Update / Delete Bill
```
GET    /bills/{id}
PUT    /bills/{id}
DELETE /bills/{id}
```

### 6.4 Mark Bill as Paid
```
POST /bills/{id}/pay
```
**Body (optional):**
```json
{
  "payment_method": "venmo"
}
```

### 6.5 Partial Payment
```
POST /bills/{id}/partial-pay
```
**Body:**
```json
{
  "amount": 25.00,
  "payment_method": "cash"
}
```

---

## Step 7 — Settlements APIs

### 7.1 List Settlements
```
GET /settlements
```

### 7.2 Record a Settlement (Settle Up)
```
POST /settlements
```
**Body:**
```json
{
  "payee_id": 2,
  "group_id": 1,
  "amount": 45.00,
  "currency": "USD",
  "payment_method": "venmo",
  "payment_reference": "@alice-venmo",
  "notes": "Paying back for Bali trip",
  "settlement_date": "2026-06-11"
}
```

`payment_method` options: `cash` | `bank_transfer` | `venmo` | `paypal` | `zelle` | `cashapp` | `apple_pay` | `other`

### 7.3 Get Settlement
```
GET /settlements/{id}
```

### 7.4 List Payment Requests
```
GET /settlements/requests
```

### 7.5 Send Payment Request
```
POST /settlements/requests
```
**Body:**
```json
{
  "debtor_id": 3,
  "group_id": 1,
  "amount": 30.00,
  "currency": "USD",
  "message": "Hey Bob, please settle the Bali hotel share 🙏"
}
```

### 7.6 Accept Payment Request
```
PUT /settlements/requests/{id}/accept
```
**Body (optional):**
```json
{
  "payment_method": "cashapp",
  "payment_reference": "$bobsmith"
}
```
> Automatically creates a settlement record and updates the ledger.

### 7.7 Decline Payment Request
```
PUT /settlements/requests/{id}/decline
```

---

## Step 8 — Activity Feed APIs

> **Auto-logging:** Activity entries are created automatically when users perform actions — no separate POST endpoint needed. Creating an expense, bill, settlement, joining a group, etc. will populate the feed.

| Action | `event_type` logged |
|---|---|
| Create expense | `expense_added` |
| Edit expense | `expense_edited` |
| Delete expense | `expense_deleted` |
| Create bill | `bill_created` |
| Pay bill | `bill_paid` |
| Record settlement | `settlement_recorded` |
| Send payment request | `settlement_requested` |
| Create group | `group_created` |
| Archive group | `group_archived` |
| Join / invite member | `member_joined` |
| Leave / remove member | `member_left` |

### 8.1 My Global Feed (all groups)
```
GET /activity
GET /activity?page=2
```

### 8.2 Group Activity Feed
```
GET /groups/{id}/activity
```

**Response item structure:**
```json
{
  "id": 1,
  "event_type": "expense_added",
  "description": "John added 'Dinner at Nobu' ($120.00)",
  "amount": "120.00",
  "currency": "USD",
  "actor": { "id": 1, "name": "John Doe", "avatar": null },
  "group": { "id": 1, "name": "Bali Trip" },
  "created_at": "2026-06-11T20:00:00Z"
}
```

`event_type` values:
`expense_added` · `expense_edited` · `expense_deleted` · `bill_created` · `bill_paid` · `settlement_recorded` · `settlement_requested` · `member_joined` · `member_left` · `group_created` · `group_archived`

---

## Step 9 — Notifications APIs

> **Auto-creation:** In-app notifications are created automatically when relevant events occur (expense added, settlement received, payment request, etc.). Respects each user's **notification settings** (`GET /user/notification-settings`) and per-group **mute** (`PUT /groups/{id}/mute-notifications`).

| Event | Notification `type` | Recipients |
|---|---|---|
| Expense added | `expense_added` | All split participants except actor |
| Expense edited/deleted | `expense_edited` | All split participants except actor |
| Bill created / paid | `bill_reminder` | Bill split members except actor |
| Settlement recorded | `settlement_received` | Payee |
| Payment request sent | `settlement_requested` | Debtor |
| Member joined | `member_joined` | Other group members |
| Group created / archived | `group_invitation` / `member_joined` | Other group members |

### 9.1 List Notifications
```
GET /notifications
GET /notifications?page=2
```

### 9.2 Mark One as Read
```
PUT /notifications/{id}/read
```

### 9.3 Mark All as Read
```
POST /notifications/read-all
```

### 9.4 Unread Count (for badge)
```
GET /notifications/unread-count
```
**Response:**
```json
{
  "data": { "count": 7 }
}
```

---

## Step 10 — Reports APIs

### 10.1 Personal Report
```
GET /reports/personal
GET /reports/personal?from=2026-06-01&to=2026-06-30
```

**Response:**
```json
{
  "data": {
    "period": { "from": "2026-06-01", "to": "2026-06-30" },
    "total_spent": 450.00,
    "total_owed": 320.00,
    "by_category": [
      { "name": "Food & Drink", "icon": "utensils", "color": "#f97316", "total": 180.00 }
    ],
    "by_month": [
      { "month": "2026-06", "total": 450.00 }
    ],
    "by_group": [
      { "id": 1, "name": "Bali Trip", "color": null, "total": 320.00 }
    ],
    "balance_trend": [
      { "month": "2026-01", "net_balance": 50.00 },
      { "month": "2026-02", "net_balance": -20.00 },
      { "month": "2026-06", "net_balance": 124.50 }
    ]
  }
}
```

### 10.2 Group Report
```
GET /reports/group/{id}
GET /reports/group/{id}?from=2026-06-01&to=2026-06-30
```

### 10.3 Export (CSV or JSON)
```
GET /reports/export
GET /reports/export?format=csv&from=2026-06-01&to=2026-06-30
GET /reports/export?format=json
```
Returns a downloadable file.

---

## Step 11 — Dashboard API

### 11.1 Dashboard Summary
```
GET /dashboard
```

**Response:**
```json
{
  "data": {
    "balance_summary": {
      "total_you_owe": 85.50,
      "total_you_are_owed": 210.00,
      "net_balance": 124.50
    },
    "quick_stats": {
      "groups_count": 3,
      "expenses_this_month": 450.00,
      "upcoming_bills_count": 2
    },
    "upcoming_bills": [ ... ],
    "recent_activity": [ ... ]
  }
}
```

---

## Categories API

### List Categories
```
GET /categories
```
Returns system categories + user's custom categories.

**System categories:** Food & Drink · Transport · Accommodation · Entertainment · Shopping · Utilities · Health · Groceries · Education · Other

### Create Custom Category
```
POST /categories
```
**Body:**
```json
{
  "name": "Pet Care",
  "icon": "paw-print",
  "color": "#a855f7"
}
```
> Max 20 custom categories per user. Color must be a valid hex code.

### Update Custom Category
```
PUT /categories/{id}
```
**Body (partial):**
```json
{
  "name": "Pet Expenses",
  "color": "#7c3aed"
}
```
> System categories cannot be edited.

### Delete Custom Category
```
DELETE /categories/{id}
```
> System categories cannot be deleted.

---

## User Search API

### Search Users
```
GET /users/search?q=john
GET /users/search?q=john@example.com&exclude_group_id=1
```

| Param | Required | Description |
|---|---|---|
| `q` | Yes | Name or email to search (min 2 chars) |
| `exclude_group_id` | No | Exclude users already in this group |

**Response:**
```json
{
  "data": [
    { "id": 2, "name": "John Smith", "email": "john@example.com", "avatar": null }
  ]
}
```
> Returns max 15 results. Use this when adding members to a group.

---

## Payment Deep Links API

### Generate Deep Links
```
GET /settlements/deeplink?payee_id=2&amount=45.00&note=Dinner
```

**Response:**
```json
{
  "data": {
    "payee": { "id": 2, "name": "Alice", "avatar": null },
    "amount": "45.00",
    "links": {
      "venmo": {
        "available": true,
        "handle": "@alice",
        "deep_link": "venmo://paycharge?txn=pay&recipients=alice&amount=45.00&note=Dinner",
        "web_link": "https://venmo.com/alice?txn=pay&amount=45.00&note=Dinner"
      },
      "paypal": {
        "available": true,
        "email": "alice@paypal.com",
        "deep_link": "paypal://send?amount=45.00&to=alice%40paypal.com",
        "web_link": "https://paypal.me/alice%40paypal.com/45.00"
      },
      "cashapp": {
        "available": true,
        "tag": "$alice",
        "deep_link": "cashme://cash.app/PAY/alice/45.00",
        "web_link": "https://cash.app/$alice/45.00"
      },
      "zelle": {
        "available": true,
        "instructions": "Open your banking app and send to:",
        "phone": "+1234567890",
        "email": "alice@example.com",
        "amount": "45.00"
      },
      "apple_pay":  { "available": false, "reason": "V2 roadmap." },
      "google_pay": { "available": false, "reason": "V2 roadmap." }
    }
  }
}
```
> `available: false` means the payee hasn't linked that payment handle in their profile.

---

## Group Photo & Notification Mute APIs

### Upload Group Photo
```
POST /groups/{id}/photo
Content-Type: multipart/form-data
```
**Form field:** `photo` — image file (jpg/png/webp, max 5MB)  
**Admin only.**

**Response:**
```json
{
  "data": { "photo": "group-photos/abc123.jpg" }
}
```

### Mute / Unmute Group Notifications
```
PUT /groups/{id}/mute-notifications
```
**Body:**
```json
{
  "muted": true
}
```
`muted: true` → silence all push notifications from this group.  
`muted: false` → re-enable.

**Response:**
```json
{
  "data": { "notifications_muted": true },
  "message": "Notifications muted for this group."
}
```

---

## How to Test

### Option A — Postman (Recommended)

1. Download and install [Postman](https://www.postman.com/downloads/)
2. Import the file: **`postman_collection.json`** (in this project root)
3. Set the environment variable `BASE_URL` = `http://localhost/fendo/public/api/v1`
4. Run **Register** → copy `access_token` from response
5. Paste token into the `TOKEN` environment variable
6. All other requests use `{{TOKEN}}` automatically

### Option B — cURL (Terminal)

**Step 1: Register**
```bash
curl -s -X POST http://localhost/fendo/public/api/v1/auth/register \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "password": "Password1",
    "password_confirmation": "Password1"
  }'
```

**Step 2: Copy the OTP from response, verify email**
```bash
curl -s -X POST http://localhost/fendo/public/api/v1/auth/verify-otp \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "otp": "PASTE_OTP_HERE",
    "purpose": "register"
  }'
```

**Step 3: Save your token, use it in all requests**
```bash
TOKEN="1|your_token_here"

curl -s http://localhost/fendo/public/api/v1/dashboard \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN"
```

### Option C — VS Code REST Client

Install the **REST Client** extension, then open any `.http` file.

**`test.http`:**
```http
@base = http://localhost/fendo/public/api/v1
@token = PASTE_TOKEN_HERE

### Register
POST {{base}}/auth/register
Content-Type: application/json

{
  "name": "Test User",
  "email": "test@example.com",
  "password": "Password1",
  "password_confirmation": "Password1"
}

### Login
POST {{base}}/auth/login
Content-Type: application/json

{
  "email": "test@example.com",
  "password": "Password1"
}

### Get Dashboard
GET {{base}}/dashboard
Authorization: Bearer {{token}}

### Create Group
POST {{base}}/groups
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "name": "Test Group",
  "type": "friends",
  "currency": "USD"
}
```

### Option D — Laravel Tinker (Quick DB checks)

```bash
php artisan tinker
```

```php
// Check a user exists
User::where('email', 'test@example.com')->first();

// Check token count
User::first()->tokens()->count();

// Check expenses
Expense::with('splits')->first();

// Check debt ledger
DebtLedger::all();
```

---

## Quick Testing Checklist

| # | Test | Expected |
|---|------|----------|
| 1 | `POST /auth/register` | `201` + OTP in response |
| 2 | `POST /auth/verify-otp` | `200` + `access_token` |
| 3 | `GET /auth/me` with token | `200` + user object |
| 4 | `GET /auth/me` without token | `401 Unauthenticated` |
| 5 | `POST /auth/refresh` with Bearer token | `200` + new `access_token` |
| 6 | `POST /auth/refresh` without token | `401 Unauthenticated` |
| 7 | `POST /groups` | `201` + group with members |
| 8 | `POST /expenses` (equal split) | `201` + splits calculated |
| 9 | `GET /activity` after expense | Feed contains `expense_added` event |
| 10 | `GET /notifications` after expense | Notification for split participants |
| 11 | `GET /groups/{id}/balances` | `simplified: true` when `simplify_debts` enabled |
| 12 | `GET /balances` after expense | Shows who owes what |
| 13 | `POST /settlements` | `201` + ledger updated |
| 14 | `GET /dashboard` | Balance cards + recent activity |
| 15 | `GET /reports/personal` | Spending by category |
| 16 | `GET /reports/export?format=csv` | Downloads CSV file |

---

## Notes for Mobile Developers

### Token Storage
- Store the `access_token` in **secure storage** (iOS Keychain / Android Keystore)
- Never store in AsyncStorage or SharedPreferences unencrypted

### Pagination
All list endpoints return paginated results. Use `?page=2` to fetch next page. Check `last_page` to know when to stop.

### Offline Support
When offline, cache the last dashboard/groups/expenses response locally. Queue mutations (create expense, settle up) in a local queue and replay when back online.

### Error Handling
Always check `success: false` in the response. For `422` errors, the `errors` object contains field-level messages. Display these under the relevant input field.

### FCM Push Notifications
After login, immediately call `PUT /user/fcm-token` with the device token from Firebase. Re-call on every app launch in case the FCM token rotated.

### Split Method Reference
| Method | When to use |
|--------|------------|
| `equal` | Default — everyone pays the same |
| `custom` | You enter exact amounts for each person |
| `percentage` | Each person pays X% of the total |
| `shares` | Ratio-based (e.g. 3:2:1 shares) |
| `itemized` | Itemized receipt — assign each item to specific people |
