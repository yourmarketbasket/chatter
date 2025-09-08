### Backend Guide: Implementing FCM Push Notifications

This guide outlines the payload structure and logic required for sending FCM push notifications to the mobile clients for various events.

#### General Principles

1.  **FCM Tokens:** The backend is responsible for storing the FCM registration token for each user. The mobile app already provides this token via a `POST` request to `/api/users/update-fcm-token`.
2.  **Data Payload:** All push notifications should be sent as **FCM Data Messages** (using the `data` field in the FCM payload), not Notification Messages. This gives the mobile app full control over handling and displaying the notification, which is essential for custom navigation and action buttons.
3.  **Common Payload Structure:** To help the client-side code handle different notification types, we recommend a consistent base structure for the `data` payload:

    ```json
    {
      "type": "event_type_here",
      // ...other data specific to the event
    }
    ```

    The `type` field will allow the mobile app to know what kind of notification it has received and how to handle it.

---

### 1. New Message Notifications

*   **Trigger:** Send this notification to a user when they receive a new message in a chat they are a part of, and they are not currently active in that chat.
*   **Purpose:** To alert the user of a new message and allow them to navigate directly to the chat screen upon tapping the notification.

*   **Recommended `data` Payload:**
    ```json
    {
      "type": "new_message",
      "chatId": "the_id_of_the_chat_room",
      "senderId": "the_id_of_the_message_sender",
      "senderName": "Sender's Name",
      "messageContent": "The first 100 characters of the message...",
      "messageId": "the_id_of_the_new_message"
    }
    ```
    *   The `chatId` is crucial for the app to know which conversation to open.
    *   `senderName` and `messageContent` are used to construct the notification's title and body.

---

### 2. New Post Notifications

*   **Trigger:** Send this notification to a user when someone they follow creates a new post. This should be sent to all followers of the post author.
*   **Purpose:** To engage users by alerting them to new content from people they follow. Tapping the notification should navigate the user to the specific post.

*   **Recommended `data` Payload:**
    ```json
    {
      "type": "new_post",
      "postId": "the_id_of_the_new_post",
      "authorId": "the_id_of_the_post_author",
      "authorName": "Author's Name",
      "postExcerpt": "The first 100 characters of the post content..."
    }
    ```
    *   The `postId` will allow the app to navigate directly to the post's detail view.

---

### 3. App Update Notifications

*   **Trigger:** Send this notification when an admin uses the "Issue Nudge" functionality from the admin panel.
*   **Purpose:** To inform users about a mandatory or recommended app update and provide a direct link to update.

*   **Recommended `data` Payload with Action Button:**
    To include a button, you need to structure the FCM payload to define a notification with an action. The exact implementation can vary slightly between APNs (for iOS) and FCM (for Android), but the principle is the same.

    ```json
    {
      "type": "app_update",
      "version": "1.2.4",
      "title": "New Update Available!",
      "body": "A new version of Chatter is available. Tap 'Update Now' to get the latest features.",
      "update_url": "https://chatter.dev/upgrade",
      "action_button_title": "Update Now"
    }
    ```
    *   `update_url`: This is the critical piece of data. It's the link that the app will open when the user taps the action button.
    *   `action_button_title`: The text to display on the button (e.g., "Update Now").

    The backend, when constructing the final FCM message, should use this data to populate the platform-specific notification fields that create a button. For example, in the generic FCM HTTP v1 API, you might structure part of the `message` object like this:

    ```json
    // Inside the main FCM payload...
    "android": {
      "notification": {
        "title": "New Update Available!",
        "body": "A new version of Chatter is available. Tap 'Update Now' to get the latest features.",
        "click_action": "FLUTTER_NOTIFICATION_CLICK"
      }
    },
    "apns": {
      "payload": {
        "aps": {
          "alert": {
            "title": "New Update Available!",
            "body": "A new version of Chatter is available. Tap 'Update Now' to get the latest features."
          },
          "category": "UPDATE_ACTION" // iOS uses categories for actions
        }
      }
    },
    "data": {
      // The full data payload as described above
      "type": "app_update",
      "version": "1.2.4",
      "update_url": "https://chatter.dev/upgrade",
      "action_button_title": "Update Now"
    }
    ```
    The mobile client is already configured to handle the `data` payload. When a notification with `type: "app_update"` is received, it will use the `update_url` to navigate the user to the correct update page when the notification or its action button is tapped.
