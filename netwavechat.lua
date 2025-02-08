-- netwavechat.lua
-- A Lua-based chat server implementing NetWaveChat
-- Dependencies: LuaSocket and LuaFileSystem (lfs)
-- Install them via LuaRocks:
--    luarocks install luasocket
--    luarocks install luafilesystem

local socket = require("socket")
local lfs = require("lfs")

-- Initialize random seed for token generation
math.randomseed(os.time())

---------------------------------------------------------------------
-- Global configuration
local PORT = 8080
local TOKEN_TIMEOUT = 30 * 60         -- 30 minutes (in seconds)
local CHATROOM_INACTIVITY = 24 * 60 * 60  -- 24 hours (in seconds)
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Logging Function
-- Logs messages to both the console and a log file.
local function log_event(event)
  local msg = os.date("%Y-%m-%d %H:%M:%S") .. " " .. event
  print(msg)  -- Output to the console
  local logfile = io.open("netwavechat.log", "a")
  if logfile then
    logfile:write(msg .. "\n")
    logfile:close()
  end
end

---------------------------------------------------------------------
-- Dummy file locking functions (placeholders for production)
local function lock_file(filename)
  -- Implement file locking if needed.
end
local function unlock_file(filename)
  -- Release file lock.
end

---------------------------------------------------------------------
-- User Management Module
local UserManager = {}
UserManager.users_file = "users.txt"  -- Users are stored in this file.

-- Each user record is stored as:
-- username|password|bio|away|logged_in|token|last_activity
function UserManager.load_users()
  local users = {}
  local file = io.open(UserManager.users_file, "r")
  if file then
    for line in file:lines() do
      local username, password, bio, away, logged_in, token, last_activity =
          line:match("([^|]+)|([^|]+)|([^|]*)|([^|]*)|([^|]+)|([^|]*)|([^|]+)")
      if username then
        users[username] = {
          username = username,
          password = password,
          bio = bio,
          away = away,
          logged_in = (logged_in == "true"),
          token = token,
          last_activity = tonumber(last_activity)
        }
      end
    end
    file:close()
  end
  return users
end

function UserManager.save_users(users)
  local file = io.open(UserManager.users_file, "w")
  for _, user in pairs(users) do
    file:write(string.format("%s|%s|%s|%s|%s|%s|%d\n",
      user.username, user.password, user.bio or "", user.away or "",
      tostring(user.logged_in), user.token or "", user.last_activity or 0))
  end
  file:close()
end

-- New user registration: /signup/{username}/{password}
function UserManager.signup(username, password)
  local users = UserManager.load_users()
  if users[username] then
    return false, "ERR_USERNAME_TAKEN"
  end
  users[username] = {
    username = username,
    password = password,
    bio = "",
    away = "",
    logged_in = false,
    token = "",
    last_activity = 0
  }
  UserManager.save_users(users)
  log_event("New user signup: " .. username)
  return true, "OK"
end

-- Login: /login/{username}/{password}
function UserManager.login(username, password)
  local users = UserManager.load_users()
  local user = users[username]
  if not user or user.password ~= password then
    return false, "ERR_INVALID_CREDENTIALS"
  end
  -- Generate a simple random token (concatenating a random number with the current time)
  local token = tostring(math.random(100000, 999999)) .. tostring(os.time())
  user.token = token
  user.logged_in = true
  user.last_activity = os.time()
  UserManager.save_users(users)
  log_event("User logged in: " .. username)
  return true, token
end

-- Validate token and update activity timestamp.
-- Returns (bool, message, username)
function UserManager.validate_token(token)
  local users = UserManager.load_users()
  for _, user in pairs(users) do
    if user.token == token then
      if os.time() - user.last_activity > TOKEN_TIMEOUT then
        return false, "ERR_TOKEN_TIMEOUT", nil
      else
        user.last_activity = os.time()
        UserManager.save_users(users)
        return true, "OK", user.username
      end
    end
  end
  return false, "ERR_INVALID_TOKEN", nil
end

---------------------------------------------------------------------
-- Message Handling Module
local MessageHandler = {}

-- Directories for inboxes and chatrooms:
MessageHandler.inbox_dir = "inboxes/"
MessageHandler.chat_dir = "chatrooms/"

-- Ensure that required directories exist.
local function ensure_directory(dir)
  local attr = lfs.attributes(dir)
  if not attr then
    os.execute("mkdir " .. dir)
  end
end
ensure_directory(MessageHandler.inbox_dir)
ensure_directory(MessageHandler.chat_dir)

-- Return the inbox filename for a given user.
function MessageHandler.get_inbox_file(username)
  return MessageHandler.inbox_dir .. username .. "_inbox.txt"
end

-- Return the chatroom filename.
function MessageHandler.get_chat_file(chatroom)
  return MessageHandler.chat_dir .. chatroom .. ".txt"
end

-- Send a private message.
-- Message format: message_number|sender|text|timestamp|status
function MessageHandler.send_private(sender, recipient, text)
  local recipient_inbox = MessageHandler.get_inbox_file(recipient)
  local next_msg_num = 1
  local file = io.open(recipient_inbox, "r")
  if file then
    for line in file:lines() do
      local msg_num = line:match("^(%d+)|")
      if msg_num then
        local num = tonumber(msg_num)
        if num >= next_msg_num then next_msg_num = num + 1 end
      end
    end
    file:close()
  end
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local message_line = string.format("%d|%s|%s|%s|unsent", next_msg_num, sender, text, timestamp)
  file = io.open(recipient_inbox, "a")
  file:write(message_line .. "\n")
  file:close()
  log_event("Private message from " .. sender .. " to " .. recipient)
  return "OK"
end

-- Get new (unsent) messages from the user's inbox and mark them as sent.
function MessageHandler.get_new_messages(username)
  local inbox_file = MessageHandler.get_inbox_file(username)
  local all_lines = {}
  local new_messages = {}
  local file = io.open(inbox_file, "r")
  if file then
    for line in file:lines() do
      table.insert(all_lines, line)
      local _, _, _, _, status = line:match("^(%d+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
      if status == "unsent" then
        table.insert(new_messages, line)
      end
    end
    file:close()
  end
  -- Mark unsent messages as sent by rewriting the file.
  local updated_lines = {}
  for _, line in ipairs(all_lines) do
    local msg_num, sender, text, timestamp, status = line:match("^(%d+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
    if status == "unsent" then
      line = string.format("%s|%s|%s|%s|sent", msg_num, sender, text, timestamp)
    end
    table.insert(updated_lines, line)
  end
  file = io.open(inbox_file, "w")
  for _, line in ipairs(updated_lines) do
    file:write(line .. "\n")
  end
  file:close()
  return new_messages
end

-- Get all messages from the user's inbox.
function MessageHandler.get_all_messages(username)
  local inbox_file = MessageHandler.get_inbox_file(username)
  local messages = {}
  local file = io.open(inbox_file, "r")
  if file then
    for line in file:lines() do
      table.insert(messages, line)
    end
    file:close()
  end
  return messages
end

-- Create a new chat room.
function MessageHandler.create_chat_room(username, chatroom)
  local chat_file = MessageHandler.get_chat_file(chatroom)
  if io.open(chat_file, "r") then
    return false, "ERR_CHATROOM_EXISTS"
  end
  local file = io.open(chat_file, "w")
  file:close()
  log_event("Chat room created: " .. chatroom .. " by " .. username)
  return true, "OK"
end

-- List all available chat rooms.
function MessageHandler.list_chat_rooms()
  local rooms = {}
  for file in lfs.dir(MessageHandler.chat_dir) do
    if file:match("%.txt$") then
      local chatroom = file:gsub("%.txt$", "")
      table.insert(rooms, chatroom)
    end
  end
  return rooms
end

-- In-memory mapping for active chat rooms (per user).
MessageHandler.active_chat_rooms = {}

function MessageHandler.set_active_chat_room(username, chatroom)
  MessageHandler.active_chat_rooms[username] = chatroom
end

function MessageHandler.get_active_chat_room(username)
  return MessageHandler.active_chat_rooms[username]
end

-- Retrieve chat messages from the active chat room.
function MessageHandler.get_chat_messages(username)
  local chatroom = MessageHandler.get_active_chat_room(username)
  if not chatroom then
    return false, "ERR_NO_ACTIVE_CHATROOM"
  end
  local chat_file = MessageHandler.get_chat_file(chatroom)
  local messages = {}
  local file = io.open(chat_file, "r")
  if file then
    for line in file:lines() do
      table.insert(messages, line)
    end
    file:close()
  else
    return false, "ERR_CHATROOM_NOT_FOUND"
  end
  return true, messages
end

-- Post a message to the active chat room.
function MessageHandler.post_chat_message(username, text)
  local chatroom = MessageHandler.get_active_chat_room(username)
  if not chatroom then
    return false, "ERR_NO_ACTIVE_CHATROOM"
  end
  local chat_file = MessageHandler.get_chat_file(chatroom)
  local next_msg_num = 1
  local file = io.open(chat_file, "r")
  if file then
    for line in file:lines() do
      local msg_num = line:match("^(%d+)|")
      if msg_num then
        local num = tonumber(msg_num)
        if num >= next_msg_num then next_msg_num = num + 1 end
      end
    end
    file:close()
  end
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local message_line = string.format("%d|%s|%s|%s", next_msg_num, username, text, timestamp)
  file = io.open(chat_file, "a")
  file:write(message_line .. "\n")
  file:close()
  log_event("Chat message posted in " .. chatroom .. " by " .. username)
  return true, "OK"
end

---------------------------------------------------------------------
-- Command Parsing Module
local CommandParser = {}

-- Split the URL path into parts.
function CommandParser.parse(url)
  local path = url:match("([^?]+)")
  path = path:gsub("^/+", ""):gsub("/+$", "")
  local parts = {}
  for part in string.gmatch(path, "[^/]+") do
    table.insert(parts, part)
  end
  return parts
end

-- Process commands based on URL parts.
function CommandParser.process(parts)
  -- Signup: /signup/{username}/{password}
  if parts[1] == "signup" then
    if #parts < 3 then return "ERR_MALFORMED_COMMAND" end
    local username = parts[2]
    local password = parts[3]
    if #username > 200 or #password > 200 then
      return "ERR_MALFORMED_COMMAND"
    end
    local success, msg = UserManager.signup(username, password)
    return success and "OK" or msg
  end

  -- Login: /login/{username}/{password}
  if parts[1] == "login" then
    if #parts < 3 then return "ERR_MALFORMED_COMMAND" end
    local username = parts[2]
    local password = parts[3]
    if #username > 200 or #password > 200 then
      return "ERR_MALFORMED_COMMAND"
    end
    local success, result = UserManager.login(username, password)
    return success and result or result
  end

  -- All other commands require a valid token.
  local token = parts[1]
  if #token > 200 then return "ERR_MALFORMED_COMMAND" end
  local valid, msg, username = UserManager.validate_token(token)
  if not valid then
    return msg
  end

  -- Dispatch commands based on the next URL part.
  local command = parts[2]
  if command == "get" then
    local messages = MessageHandler.get_new_messages(username)
    if #messages == 0 then
      return "NO_NEW_MESSAGES"
    else
      return table.concat(messages, "\n")
    end
  elseif command == "getall" then
    local messages = MessageHandler.get_all_messages(username)
    if #messages == 0 then
      return "NO_MESSAGES"
    else
      return table.concat(messages, "\n")
    end
  elseif command == "msg" then
    if #parts < 4 then return "ERR_MALFORMED_COMMAND" end
    local recipient = parts[3]
    local text = parts[4]:gsub("~", " ")  -- Convert tilde back to space
    if #text > 200 then return "ERR_MESSAGE_TOO_LONG" end
    return MessageHandler.send_private(username, recipient, text)
  elseif command == "newchat" then
    if #parts < 3 then return "ERR_MALFORMED_COMMAND" end
    local chatroom = parts[3]
    local success, msg = MessageHandler.create_chat_room(username, chatroom)
    if success then
      MessageHandler.set_active_chat_room(username, chatroom)
      return "OK"
    else
      return msg
    end
  elseif command == "chatls" then
    local rooms = MessageHandler.list_chat_rooms()
    if #rooms == 0 then
      return "NO_CHATROOMS"
    else
      return table.concat(rooms, "\n")
    end
  elseif command == "chat" then
    if #parts < 3 then return "ERR_MALFORMED_COMMAND" end
    local subcommand = parts[3]
    if subcommand == "get" then
      local success, result = MessageHandler.get_chat_messages(username)
      if not success then
        return result
      elseif #result == 0 then
        return "NO_CHAT_MESSAGES"
      else
        return table.concat(result, "\n")
      end
    elseif subcommand == "post" then
      if #parts < 4 then return "ERR_MALFORMED_COMMAND" end
      local text = parts[4]:gsub("~", " ")
      if #text > 200 then return "ERR_MESSAGE_TOO_LONG" end
      local success, result = MessageHandler.post_chat_message(username, text)
      return success and "OK" or result
    else
      return "ERR_MALFORMED_COMMAND"
    end
  else
    return "ERR_MALFORMED_COMMAND"
  end
end

---------------------------------------------------------------------
-- Cleanup Module
-- This routine deletes inactive chat rooms and purges old messages.
local function cleanup()
  -- Delete chat room files inactive for more than 24 hours.
  for file in lfs.dir(MessageHandler.chat_dir) do
    if file:match("%.txt$") then
      local full_path = MessageHandler.chat_dir .. file
      local attr = lfs.attributes(full_path)
      if attr and (os.time() - attr.modification > CHATROOM_INACTIVITY) then
        os.remove(full_path)
        log_event("Deleted inactive chat room: " .. file)
      end
    end
  end
  -- Clean old messages in user inboxes.
  for file in lfs.dir(MessageHandler.inbox_dir) do
    if file:match("_inbox%.txt$") then
      local full_path = MessageHandler.inbox_dir .. file
      local new_lines = {}
      local modified = false
      local f = io.open(full_path, "r")
      if f then
        for line in f:lines() do
          local msg_num, sender, text, timestamp, status = line:match("^(%d+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
          if timestamp then
            local year = tonumber(timestamp:sub(1,4))
            local month = tonumber(timestamp:sub(6,7))
            local day = tonumber(timestamp:sub(9,10))
            local hour = tonumber(timestamp:sub(12,13))
            local min = tonumber(timestamp:sub(15,16))
            local sec = tonumber(timestamp:sub(18,19))
            local msg_time = os.time({year=year, month=month, day=day, hour=hour, min=min, sec=sec})
            if os.time() - msg_time <= CHATROOM_INACTIVITY then
              table.insert(new_lines, line)
            else
              modified = true
            end
          else
            table.insert(new_lines, line)
          end
        end
        f:close()
        if modified then
          local f2 = io.open(full_path, "w")
          for _, l in ipairs(new_lines) do
            f2:write(l .. "\n")
          end
          f2:close()
          log_event("Cleaned up old messages in inbox: " .. file)
        end
      end
    end
  end
end

---------------------------------------------------------------------
-- Main Server Loop
local server = assert(socket.bind("*", PORT))
server:settimeout(0)
log_event("Server started on port " .. PORT)
log_event("Listening on all interfaces. Use http://<server-ip>:" .. PORT .. "/ to access.")

local running = true
local main_loop = function()
  while running do
    local client = server:accept()
    if client then
      client:settimeout(1)
      local request, err = client:receive("*l")
      if request then
        -- Expect a request line like: GET /path HTTP/1.1
        local method, url = request:match("^(%S+)%s+(%S+)")
        if method ~= "GET" then
          client:send("HTTP/1.1 405 Method Not Allowed\r\n\r\n")
          client:close()
        else
          local parts = CommandParser.parse(url)
          local response_body = CommandParser.process(parts)
          local response = "HTTP/1.1 200 OK\r\n" ..
                           "Content-Type: text/plain\r\n" ..
                           "Content-Length: " .. tostring(#response_body) .. "\r\n\r\n" ..
                           response_body
          client:send(response)
          client:close()
        end
      else
        client:close()
      end
    end
    socket.sleep(0.1)
  end
end

-- Run the main loop in a protected call to help suppress shutdown traceback errors.
local status, err = pcall(main_loop)
if not status then
  log_event("Server error: " .. tostring(err))
end

log_event("Server shutting down.")
