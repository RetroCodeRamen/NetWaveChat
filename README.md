NetWaveChat
NetWaveChat is a Lua‑based chat server designed for real‑time messaging among multiple users. Due to client platform restrictions, all interactions are performed via HTTPS GET requests. Every command is specified in the URL path, and each parameter is limited to 200 characters. To avoid URL space restrictions, clients must replace spaces with the tilde character (~) when sending text.

The software is divided into several modules:

User Management
Message Handling (for both private and chat room messages)
Command Parsing
Periodic Cleanup of old messages and inactive chat rooms
A simple token‑based authentication system is used: upon login, users receive a token that must be included in all subsequent commands. Tokens expire after 30 minutes of inactivity.

Table of Contents
How to Start the Server
Installation and Dependencies
User Registration and Authentication
Private Messaging (User Inboxes)
Chat Room Functionality
Token Validation and Activity
Message and File Storage Details
Error Handling
Additional Functional Details
Summary of Functionality
How to Use the System
How to Start the Server
Prerequisites
Lua: Ensure you have Lua installed on your system.
LuaRocks: Ensure that LuaRocks is installed to manage dependencies.
Installing Lua and LuaRocks
On Linux
Install Lua (if not already installed):

For Debian/Ubuntu:
bash
Copy
sudo apt-get update
sudo apt-get install lua5.3
For Fedora:
bash
Copy
sudo dnf install lua
Alternatively, compile Lua from source if needed.
Install LuaRocks:

For Debian/Ubuntu:
bash
Copy
sudo apt-get install luarocks
Alternatively, install LuaRocks from source following the instructions at LuaRocks.org.
On Windows
Install Lua:

Download the Windows Lua binaries from LuaBinaries.
Follow the provided installation instructions.
Install LuaRocks:

Download the LuaRocks Windows installer from the LuaRocks website.
Run the installer and follow the prompts.
Setting Up and Starting the Server
Copy the File Contents:

Copy the entire NetWaveChat server code (or file contents) and save it as a file named netwavechat.lua.
Navigate to the File Location:

Open a terminal (Command Prompt on Windows or Terminal on Linux).
Change directory (cd) to the folder containing netwavechat.lua.
Install Dependencies via LuaRocks:

Run the following commands to install the required modules:
bash
Copy
luarocks install luasocket
luarocks install luafilesystem
Start the Server:

Execute the following command in your terminal:
bash
Copy
lua netwavechat.lua
The server should start and begin listening for HTTPS GET requests.
Example
On Linux:
bash
Copy
cd /path/to/netwavechat
luarocks install luasocket
luarocks install luafilesystem
lua netwavechat.lua
On Windows:
Open Command Prompt.
Navigate to the folder where netwavechat.lua is saved:
cmd
Copy
cd C:\path\to\netwavechat
Then run:
cmd
Copy
lua netwavechat.lua
Installation and Dependencies
LuaSocket
NetWaveChat uses LuaSocket for network communication. To install LuaSocket, use LuaRocks:

bash
Copy
luarocks install luasocket
Then, import it in your Lua code:

lua
Copy
local socket = require("socket")
LuaFileSystem (lfs)
The server uses LuaFileSystem for directory and file attribute operations. Install it via LuaRocks:

bash
Copy
luarocks install luafilesystem
Then, import it in your script:

lua
Copy
local lfs = require("lfs")
Note: Make sure that LuaRocks is installed on your system. Installing dependencies via LuaRocks ensures that your code can import them correctly.

User Registration and Authentication
Signup (User Registration)
Endpoint:

perl
Copy
https://<server-address>/signup/{username}/{password}
Usage:

Use this endpoint to create a new user account. Replace {username} and {password} with the desired values.
Example:

ruby
Copy
https://localhost/signup/johndoe/mysecret
Implementation Details:

The server checks the users file to see if the username already exists.
If the username is available, a new record is created (with fields such as bio, away message, login status, token, and last activity timestamp).
If the username is taken, the server returns ERR_USERNAME_TAKEN.
Response:

Returns OK on success or an error code (such as ERR_USERNAME_TAKEN) if there is a problem.
Login (Authentication)
Endpoint:

pgsql
Copy
https://<server-address>/login/{username}/{password}
Usage:

Log in to your account by providing your username and password.
Example:

ruby
Copy
https://localhost/login/johndoe/mysecret
Implementation Details:

The server verifies the credentials against the users file.
On successful login, the server generates a random token and records the current time as the last activity.
The token is returned to the client and must be used in all future requests.
Note: Passwords are stored in plain text in this version (future versions may implement hashing).
Response:

On success, the response is the generated token (a string). On failure, an error such as ERR_INVALID_CREDENTIALS is returned.
Private Messaging (User Inboxes)
Get New Messages (Inbox)
Endpoint:

perl
Copy
https://<server-address>/{token}/get/
Usage:

Retrieve messages from your inbox that have not yet been marked as “sent.”
Example:

bash
Copy
https://localhost/a5hw16/get/
(Here, a5hw16 represents your token.)

Implementation Details:

The server validates the token (including checking that it hasn’t expired).
All messages in the inbox with a status of unsent are read.
After sending these messages to the client, the server marks them as sent.
Sequential numbering is maintained to ensure message order.
Response:

Returns a list of unsent messages. If no new messages exist, you receive NO_NEW_MESSAGES.
Get All Messages (Inbox)
Endpoint:

perl
Copy
https://<server-address>/{token}/getall/
Usage:

Retrieve all messages in your inbox, regardless of whether they have been marked as sent.
Example:

bash
Copy
https://localhost/a5hw16/getall/
Implementation Details:

The entire inbox file is read.
No messages are modified (i.e. no marking of messages is done).
Response:

Returns the complete message history for your inbox or NO_MESSAGES if your inbox is empty.
Send Private Message
Endpoint:

perl
Copy
https://<server-address>/{token}/msg/{recipientUsername}/{textBody}
Usage:

To send a private message to another user, replace {recipientUsername} with the recipient’s username and {textBody} with your message text.
Example:

bash
Copy
https://localhost/a5hw16/msg/janedoe/Hello~Jane!
(Here, Hello~Jane! is interpreted as “Hello Jane!” because tildes replace spaces.)

Implementation Details:

The sender’s token is validated.
The server checks that the text body does not exceed 200 characters.
The message is appended to the recipient’s inbox file with a sequential message number and a timestamp.
The message-sending event is logged.
Response:

Returns OK if the message is successfully delivered or an appropriate error code (e.g., if the recipient does not exist or the message is too long).
Chat Room Functionality
Create New Chat Room
Endpoint:

perl
Copy
https://<server-address>/{token}/newchat/{chatroomname}
Usage:

Create a new chat room by specifying a name. Once created, this chat room becomes the active chat room for your session.
Example:

bash
Copy
https://localhost/a5hw16/newchat/General
Implementation Details:

The server verifies that a chat room with the same name does not already exist.
A new file is created in the chat room directory.
The active chat room for the user is set in memory (clients are expected to remember the active chat room).
Response:

Returns OK on successful creation or an error code (such as ERR_CHATROOM_EXISTS) if a room with that name already exists.
List All Chat Rooms
Endpoint:

perl
Copy
https://<server-address>/{token}/chatls/
Usage:

Retrieve a list of all available chat rooms on the server.
Example:

bash
Copy
https://localhost/a5hw16/chatls/
Implementation Details:

The server scans the chat rooms directory and returns the names of all chat room files.
If no chat rooms exist, a message indicating NO_CHATROOMS is returned.
Response:

A newline‑separated list of chat room names, or NO_CHATROOMS if none are available.
Retrieve Chat Room Messages
Endpoint:

perl
Copy
https://<server-address>/{token}/chat/get/
Usage:

Retrieve messages from your currently active chat room.
Example:

bash
Copy
https://localhost/a5hw16/chat/get/
Implementation Details:

The server first checks that an active chat room has been set for your session.
It reads all messages from the corresponding chat room file.
Each message is sequentially numbered.
If the active chat room isn’t set or does not exist, an error is returned.
Response:

A newline‑separated list of messages or an error code such as ERR_NO_ACTIVE_CHATROOM if no active room is set.
Post Message to Chat Room
Endpoint:

css
Copy
https://<server-address>/{token}/chat/post/{body}
Usage:

Post a message to your active chat room. Replace {body} with the message text (remember to use tilde characters (~) for spaces).
Example:

bash
Copy
https://localhost/a5hw16/chat/post/Hello~everyone!
Implementation Details:

The token is validated and the server checks that you have an active chat room.
The message text is verified to be within the 200‑character limit.
The message is appended to the chat room file with a new sequential number and timestamp.
The event is logged.
Response:

Returns OK on success or an error (such as ERR_NO_ACTIVE_CHATROOM) if no active chat room is set.
Token Validation and Activity
Token Generation
When you log in, the server generates a random token (using a random number concatenated with a timestamp) and returns it to you.
You must include this token as the first segment in every command (except for signup and login).
Token Expiration
Tokens expire after 30 minutes of inactivity.
If you attempt any operation with an expired token, you will receive the error code ERR_TOKEN_TIMEOUT.
Activity Update
Every valid command updates your user’s “last activity” timestamp, thereby extending the token’s lifetime.
Message and File Storage Details
Private Messages (User Inboxes)
Storage:

Each user has an individual inbox file stored in a designated directory (e.g., inboxes/username_inbox.txt).
Message Format:

Each line in the inbox file is stored as:

pgsql
Copy
message_number|sender|text|timestamp|status
The status is either unsent (if not yet retrieved) or sent.

Retrieval:

The /get/ command retrieves and marks unsent messages as sent, while /getall/ shows the complete history.
Chat Rooms
Storage:

Chat rooms are stored as files (e.g., chatrooms/General.txt).
Message Format:

Each chat room message is stored as:

pgsql
Copy
message_number|sender|text|timestamp
Messages are sequentially numbered in the order they are received.

Chat Room Lifetime:

Chat room files with no activity for 24 hours are automatically deleted by the cleanup process.
Error Handling
NetWaveChat returns plain‑text error codes when something goes wrong. Some common error responses include:

ERR_USERNAME_TAKEN – The chosen username already exists.
ERR_INVALID_CREDENTIALS – Login failed due to incorrect username or password.
ERR_INVALID_TOKEN – The token provided is not recognized.
ERR_TOKEN_TIMEOUT – Your token has expired (30 minutes of inactivity).
ERR_MALFORMED_COMMAND – The URL command does not match the expected format.
ERR_MESSAGE_TOO_LONG – The message text exceeds the 200‑character limit.
ERR_CHATROOM_EXISTS – A chat room with that name already exists.
ERR_NO_ACTIVE_CHATROOM – No active chat room has been set for your session.
ERR_CHATROOM_NOT_FOUND – The requested chat room does not exist.
Additional Functional Details
Communication Protocol and Limitations
HTTPS GET Requests Only: All commands are executed via HTTPS GET requests. The server expects URL paths (everything after the domain) to encode the command and its parameters.
Parameter Length: Each parameter is limited to 200 characters. Ensure that your username, password, and message text adhere to this limit.
Tilde Character Usage: Due to URL encoding limitations, replace spaces with the tilde character (~) when sending message text.
Cleanup and Maintenance
Cleanup Process:

The server periodically runs a cleanup routine (ideally on an hourly schedule) to:
Delete chat room files that have been inactive for over 24 hours.
Remove or archive private messages older than 24 hours.
During cleanup, write operations may be queued and paused to maintain file integrity.
Logging:

Significant events (user logins, signups, message sending, chat room creation, and cleanup operations) are logged to a plain text log file (netwavechat.log).
Summary of Functionality
User Registration and Authentication: New users can sign up and then log in to receive a token. All subsequent commands require a valid token.
Private Messaging: Users can send and receive private messages. New messages are automatically marked as “sent” once retrieved.
Chat Rooms: Users can create chat rooms, list available chat rooms, set an active chat room, retrieve messages from the active room, and post new messages. All messages are sequentially numbered.
Token Management: Tokens are refreshed with every valid command but expire after 30 minutes of inactivity, requiring users to log in again if needed.
Error Reporting: The system returns clear, plain‑text error messages for malformed commands, expired tokens, and other issues.
Scalability Considerations: While the current implementation uses file‑based storage with simple file locking, the design anticipates future migration to in‑memory caches or databases as user load increases.
How to Use the System
Install Dependencies:

Ensure that LuaSocket and LuaFileSystem are installed using LuaRocks:
bash
Copy
luarocks install luasocket
luarocks install luafilesystem
Create an Account:

Send a GET request to:
bash
Copy
/signup/{username}/{password}
Log In:

Use the endpoint:
pgsql
Copy
/login/{username}/{password}
to log in and obtain your token.
Start Messaging:

Private Messaging:

To send a private message:
swift
Copy
/{token}/msg/{recipient}/{message}
To check for new private messages:
swift
Copy
/{token}/get/
To review all private messages:
bash
Copy
/{token}/getall/
Chat Rooms:

To create a new chat room and set it as active:
bash
Copy
/{token}/newchat/{chatroomname}
To list all chat rooms:
bash
Copy
/{token}/chatls/
To retrieve chat messages from your active chat room:
swift
Copy
/{token}/chat/get/
To post a message to your active chat room:
swift
Copy
/{token}/chat/post/{message}
Keep Your Session Active:

Every command updates your last activity timestamp. If you’re inactive for 30 minutes, your token expires and you must log in again.
Happy chatting with NetWaveChat!
