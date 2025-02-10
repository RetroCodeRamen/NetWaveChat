# NetWaveChat

NetWaveChat is a Lua‑based chat server for real‑time messaging among multiple users. All interactions are performed via HTTPS GET requests, and each parameter is limited to 200 characters. To work around URL encoding limitations, spaces in text must be replaced with the tilde character (`~`).

The server supports:
- **User Management**
- **Message Handling** (for both private and chat room messages)
- **Command Parsing**
- **Periodic Cleanup** of old messages and inactive chat rooms

A simple token‑based authentication system is used. After logging in, users receive a token that must be included in all subsequent commands. Tokens expire after 30 minutes of inactivity.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Endpoints](#endpoints)
  - [User Registration and Authentication](#user-registration-and-authentication)
  - [Private Messaging](#private-messaging)
  - [Chat Room Functionality](#chat-room-functionality)
- [Token Management](#token-management)
- [Storage Details](#storage-details)
  - [Private Messages](#private-messages)
  - [Chat Rooms](#chat-rooms)
- [Error Handling](#error-handling)
- [Additional Details](#additional-details)
- [Summary and Usage](#summary-and-usage)

---

## Getting Started

### Prerequisites
- **Lua:** Ensure that Lua is installed.
- **LuaRocks:** Install LuaRocks to manage dependencies.

### Installation

#### Linux
1. **Install Lua:**
   - *Debian/Ubuntu:*
     ```bash
     sudo apt-get update
     sudo apt-get install lua5.3
     ```
   - *Fedora:*
     ```bash
     sudo dnf install lua
     ```
2. **Install LuaRocks:**
   - *Debian/Ubuntu:*
     ```bash
     sudo apt-get install luarocks
     ```
   - Or compile LuaRocks from source.

#### Windows
1. **Install Lua:**
   - Download the Windows binaries from [LuaBinaries](http://luabinaries.sourceforge.net/).
2. **Install LuaRocks:**
   - Download and run the installer from [LuaRocks](https://luarocks.org/).

### Dependencies
Install the required modules via LuaRocks:
```bash
luarocks install luasocket
luarocks install luafilesystem
```

### Starting the Server
1. **Save the Code:** Copy the NetWaveChat code into a file named `netwavechat.lua`.
2. **Navigate to the File Location:** Open a terminal (or Command Prompt) and change directory:
   ```bash
   cd /path/to/netwavechat
   ```
3. **Run the Server:**
   ```bash
   lua netwavechat.lua
   ```
The server will start and listen for HTTPS GET requests.

---

## Endpoints

### User Registration and Authentication

#### Signup (User Registration)
**Endpoint:**
```
https://<server-address>/signup/{username}/{password}
```
**Usage:** Create a new user account.  
**Example:**
```
https://localhost/signup/johndoe/mysecret
```
- Checks if the username already exists.
- Creates a new user record (with fields such as bio, away message, login status, token, and last activity timestamp).
- Returns `OK` on success or `ERR_USERNAME_TAKEN` if the username is taken.

#### Login (Authentication)
**Endpoint:**
```
https://<server-address>/login/{username}/{password}
```
**Usage:** Log in to receive your token.  
**Example:**
```
https://localhost/login/johndoe/mysecret
```
- Verifies credentials against the user database.
- On success, generates a token (using a random number concatenated with a timestamp) and records the login time.
- Returns the token, or `ERR_INVALID_CREDENTIALS` on failure.

---

### Private Messaging

#### Retrieve New Messages (Inbox)
**Endpoint:**
```
https://<server-address>/{token}/get/
```
**Usage:** Fetch unsent messages from your inbox.  
**Example:**
```
https://localhost/a5hw16/get/
```
- Validates the token.
- Retrieves all messages marked as `unsent`, then marks them as `sent`.
- Returns the messages or `NO_NEW_MESSAGES` if there are none.

#### Retrieve All Messages (Inbox)
**Endpoint:**
```
https://<server-address>/{token}/getall/
```
**Usage:** Fetch your complete message history.  
**Example:**
```
https://localhost/a5hw16/getall/
```
- Reads the entire inbox without modifying message statuses.
- Returns all messages or `NO_MESSAGES` if the inbox is empty.

#### Send Private Message
**Endpoint:**
```
https://<server-address>/{token}/msg/{recipientUsername}/{textBody}
```
**Usage:** Send a private message (use `~` for spaces).  
**Example:**
```
https://localhost/a5hw16/msg/janedoe/Hello~Jane!
```
- Validates the sender’s token.
- Ensures the message does not exceed 200 characters.
- Appends the message (with a sequential number and timestamp) to the recipient’s inbox.
- Returns `OK` or an appropriate error if unsuccessful.

---

### Chat Room Functionality

#### Create New Chat Room
**Endpoint:**
```
https://<server-address>/{token}/newchat/{chatroomname}
```
**Usage:** Create a new chat room and set it as active.  
**Example:**
```
https://localhost/a5hw16/newchat/General
```
- Verifies that no chat room with the same name exists.
- Creates a new file for the chat room.
- Returns `OK` or `ERR_CHATROOM_EXISTS`.

#### List All Chat Rooms
**Endpoint:**
```
https://<server-address>/{token}/chatls/
```
**Usage:** Retrieve a list of all available chat rooms.  
**Example:**
```
https://localhost/a5hw16/chatls/
```
- Scans the chat room directory.
- Returns a newline‑separated list of chat room names or `NO_CHATROOMS` if none exist.

#### Retrieve Chat Room Messages
**Endpoint:**
```
https://<server-address>/{token}/chat/get/
```
**Usage:** Fetch messages from your active chat room.  
**Example:**
```
https://localhost/a5hw16/chat/get/
```
- Validates that an active chat room is set.
- Reads and returns the messages (with sequential numbering) or `ERR_NO_ACTIVE_CHATROOM` if none is set.

#### Post Message to Chat Room
**Endpoint:**
```
https://<server-address>/{token}/chat/post/{body}
```
**Usage:** Post a message to your active chat room (use `~` for spaces).  
**Example:**
```
https://localhost/a5hw16/chat/post/Hello~everyone!
```
- Validates the token and active chat room.
- Checks that the message is within the 200‑character limit.
- Appends the message (with sequential numbering and timestamp) to the chat room file.
- Returns `OK` or an error if unsuccessful.

---

## Token Management

- **Generation:** Upon successful login, a token is created using a random number and a timestamp.
- **Expiration:** Tokens expire after 30 minutes of inactivity. If expired, operations return `ERR_TOKEN_TIMEOUT`.
- **Activity Update:** Every valid command updates the user’s last activity timestamp, extending the token’s lifetime.

---

## Storage Details

### Private Messages
- **Storage:** Each user has an individual inbox file (e.g., `inboxes/username_inbox.txt`).
- **Format:** Each line is stored as:
  ```
  message_number|sender|text|timestamp|status
  ```
  - `status` is either `unsent` or `sent`.
- **Retrieval:** The `/get/` endpoint retrieves unsent messages (marking them as sent), while `/getall/` retrieves the full message history.

### Chat Rooms
- **Storage:** Chat rooms are saved as files (e.g., `chatrooms/General.txt`).
- **Format:** Each message is stored as:
  ```
  message_number|sender|text|timestamp
  ```
- **Maintenance:** Chat room files inactive for 24 hours are automatically deleted by the cleanup process.

---

## Error Handling

NetWaveChat returns plain‑text error codes when an issue occurs. Common error responses include:

- `ERR_USERNAME_TAKEN` – The username already exists.
- `ERR_INVALID_CREDENTIALS` – Incorrect username or password.
- `ERR_INVALID_TOKEN` – The provided token is not recognized.
- `ERR_TOKEN_TIMEOUT` – The token has expired (30 minutes of inactivity).
- `ERR_MALFORMED_COMMAND` – The URL command does not match the expected format.
- `ERR_MESSAGE_TOO_LONG` – The message exceeds the 200‑character limit.
- `ERR_CHATROOM_EXISTS` – A chat room with that name already exists.
- `ERR_NO_ACTIVE_CHATROOM` – No active chat room is set.
- `ERR_CHATROOM_NOT_FOUND` – The requested chat room does not exist.

---

## Additional Details

### Communication Protocol
- **HTTPS GET Requests Only:** All commands are executed via HTTPS GET requests.
- **Parameter Limit:** Each parameter is limited to 200 characters.
- **Tilde Usage:** Replace spaces with the tilde character (`~`) in text parameters.

### Cleanup and Logging
- **Cleanup Process:** Periodically deletes chat room files inactive for over 24 hours and removes or archives private messages older than 24 hours.
- **Logging:** Key events (e.g., logins, signups, message sending, chat room creation, cleanup) are logged to `netwavechat.log`.

---

## Summary and Usage

NetWaveChat provides:

- **User Registration & Authentication:** Create an account and log in to obtain a token.
- **Private Messaging:** Send and receive private messages with status tracking.
- **Chat Rooms:** Create, list, and interact in chat rooms with sequentially numbered messages.
- **Token Management:** Tokens are refreshed with each valid command but expire after 30 minutes of inactivity.
- **Error Reporting:** Clear, plain‑text error codes are returned for any issues.

### Quick Start Guide
1. **Install Dependencies:**
   ```bash
   luarocks install luasocket
   luarocks install luafilesystem
   ```
2. **Save the Code:** Copy the server code to a file named `netwavechat.lua`.
3. **Start the Server:**
   ```bash
   cd /path/to/netwavechat
   lua netwavechat.lua
   ```
4. **User Actions:**
   - **Sign Up:**  
     `https://<server-address>/signup/{username}/{password}`
   - **Log In:**  
     `https://<server-address>/login/{username}/{password}`
   - **Send Private Message:**  
     `https://<server-address>/{token}/msg/{recipient}/{message}`
   - **Check Inbox:**  
     `https://<server-address>/{token}/get/` or `https://<server-address>/{token}/getall/`
   - **Chat Rooms:**  
     - Create: `https://<server-address>/{token}/newchat/{chatroomname}`
     - List: `https://<server-address>/{token}/chatls/`
     - Retrieve: `https://<server-address>/{token}/chat/get/`
     - Post: `https://<server-address>/{token}/chat/post/{message}`

Happy chatting with NetWaveChat!
