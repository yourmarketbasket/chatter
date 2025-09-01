# Backend Route Documentation

This document outlines the required backend routes for the new admin functionalities.

---

## 1. Search User by Username

-   **Endpoint:** `/api/users/by-name/:username`
-   **Method:** `GET`
-   **Description:** Searches for a single user by their exact username.
-   **URL Parameters:**
    -   `username` (string, required): The username of the user to search for.
-   **Success Response (200):**
    ```json
    {
      "success": true,
      "user": {
        "_id": "user_id_1",
        "name": "founduser",
        "avatar": "url_to_avatar",
        "isSuspended": false,
        "verification": {
            "entityType": "individual",
            "level": "premium",
            "paid": true
        }
      }
    }
    ```
-   **Failure Response (404 - Not Found):**
    ```json
    {
      "success": false,
      "message": "User not found."
    }
    ```

---

## 2. Fetch Posts by Username

-   **Endpoint:** `/api/posts/by-user/:username`
-   **Method:** `GET`
-   **Description:** Fetches all posts by a specific user.
-   **URL Parameters:**
    -   `username` (string, required): The username of the user whose posts to fetch.
-   **Success Response (200):**
    ```json
    {
      "success": true,
      "posts": [
        {
          "_id": "post_id_1",
          "content": "This is a post.",
          "username": "founduser",
          "isFlagged": false,
          "attachments": [],
          "likes": [],
          "reposts": [],
          "views": [],
          "replies": [],
          "createdAt": "2023-10-27T10:00:00.000Z"
        }
      ]
    }
    ```
-   **Failure Response (404 - Not Found):**
    ```json
    {
      "success": false,
      "message": "User not found."
    }
    ```

---

## 3. Unsuspend User

-   **Endpoint:** `/api/users/:userId/unsuspend`
-   **Method:** `PUT`
-   **Description:** Unsuspend a user.
-   **URL Parameters:**
    -   `userId` (string, required): The ID of the user to unsuspend.
-   **Success Response (200):**
    ```json
    {
      "success": true,
      "message": "User unsuspended successfully."
    }
    ```
-   **Failure Response (400 - Bad Request):**
    ```json
    {
      "success": false,
      "message": "User not found."
    }
    ```

---

## 4. Unflag Post

-   **Endpoint:** `/api/posts/:postId/unflag`
-   **Method:** `PUT`
-   **Description:** Unflag a post.
-   **URL Parameters:**
    -   `postId` (string, required): The ID of the post to unflag.
-   **Success Response (200):**
    ```json
    {
      "success": true,
      "message": "Post unflagged successfully."
    }
    ```
-   **Failure Response (400 - Bad Request):**
    ```json
    {
      "success": false,
      "message": "Post not found."
    }
    ```
