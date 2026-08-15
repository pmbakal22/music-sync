/**
 * Music Sync Server — Socket.IO WebSocket Server
 *
 * Coordinates room-based synchronized playback across multiple devices
 * using the "Buffer Strategy" described in ARCHITECTURE.md.
 *
 * The server does NOT stream audio. It acts as a "Universal Remote" relay:
 *   1. Manages rooms identified by 4-digit codes
 *   2. Provides NTP-style clock sync via ping/pong
 *   3. Broadcasts timestamped playback commands to all room members
 *      so each client can schedule local Spotify SDK execution at
 *      the exact same future moment (targetTimestamp).
 */

const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const cors = require("cors");

// ─── Express + HTTP Server ───────────────────────────────────────────────────

const app = express();
app.use(cors());

const server = http.createServer(app);

// ─── Socket.IO Server (CORS open for dev) ────────────────────────────────────

const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

// ─── In-Memory State ─────────────────────────────────────────────────────────

/**
 * rooms: Map<roomCode, { hostSocketId, members: Set<socketId> }>
 *
 * Each room is keyed by a 4-digit string code.
 * `hostSocketId` is the socket that created the room.
 * `members` includes the host and all joiners.
 */
const rooms = new Map();

/**
 * socketRooms: Map<socketId, roomCode>
 *
 * Reverse lookup so we can clean up on disconnect without
 * iterating every room.
 */
const socketRooms = new Map();

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Generate a random 4-digit room code that doesn't collide
 * with any existing room.
 */
function generateRoomCode() {
  let code;
  do {
    code = String(Math.floor(1000 + Math.random() * 9000)); // 1000–9999
  } while (rooms.has(code));
  return code;
}

/**
 * Pretty-print the current rooms state (debug helper).
 */
function logRoomsSnapshot() {
  console.log("📊 Rooms snapshot:");
  if (rooms.size === 0) {
    console.log("   (no active rooms)");
    return;
  }
  for (const [code, room] of rooms) {
    console.log(
      `   Room ${code} — host: ${room.hostSocketId}, members: ${room.members.size}`
    );
  }
}

// ─── Socket.IO Connection Handler ────────────────────────────────────────────

io.on("connection", (socket) => {
  console.log(`🔌 Client connected: ${socket.id}`);

  // ── create_room ──────────────────────────────────────────────────────────

  socket.on("create_room", () => {
    // If the socket is already in a room, leave it first
    if (socketRooms.has(socket.id)) {
      const oldCode = socketRooms.get(socket.id);
      console.log(
        `⚠️  Socket ${socket.id} already in room ${oldCode}, leaving before creating new room`
      );
      removeFromRoom(socket, oldCode);
    }

    const roomCode = generateRoomCode();

    rooms.set(roomCode, {
      hostSocketId: socket.id,
      members: new Set([socket.id]),
    });

    socketRooms.set(socket.id, roomCode);
    socket.join(roomCode);

    socket.emit("room_created", { roomCode });

    console.log(`🏠 Room ${roomCode} created by ${socket.id}`);
    logRoomsSnapshot();
  });

  // ── join_room ────────────────────────────────────────────────────────────

  socket.on("join_room", ({ roomCode }) => {
    // Validate room exists
    if (!rooms.has(roomCode)) {
      socket.emit("error_message", {
        message: `Room ${roomCode} does not exist.`,
      });
      console.log(
        `❌ Socket ${socket.id} tried to join non-existent room ${roomCode}`
      );
      return;
    }

    // If already in another room, leave it first
    if (socketRooms.has(socket.id)) {
      const oldCode = socketRooms.get(socket.id);
      if (oldCode === roomCode) {
        socket.emit("error_message", {
          message: `You are already in room ${roomCode}.`,
        });
        console.log(
          `⚠️  Socket ${socket.id} already in room ${roomCode}, ignoring duplicate join`
        );
        return;
      }
      removeFromRoom(socket, oldCode);
    }

    const room = rooms.get(roomCode);
    room.members.add(socket.id);
    socketRooms.set(socket.id, roomCode);
    socket.join(roomCode);

    // Notify the joiner
    socket.emit("room_joined", {
      roomCode,
      memberCount: room.members.size,
    });

    // Notify everyone else in the room
    socket.to(roomCode).emit("member_joined", {
      memberId: socket.id,
      memberCount: room.members.size,
    });

    console.log(
      `👋 Socket ${socket.id} joined room ${roomCode} (${room.members.size} members)`
    );
    logRoomsSnapshot();
  });

  // ── leave_room ───────────────────────────────────────────────────────────

  socket.on("leave_room", () => {
    const roomCode = socketRooms.get(socket.id);
    if (!roomCode) {
      socket.emit("error_message", {
        message: "You are not in any room.",
      });
      return;
    }

    removeFromRoom(socket, roomCode);
    console.log(`🚪 Socket ${socket.id} left room ${roomCode}`);
    logRoomsSnapshot();
  });

  // ── play_command (Host → Server → All Clients) ──────────────────────────
  //
  // Core of the Buffer Strategy: the targetTimestamp is a future server
  // time (≈ now + 1500 ms) that every client uses to schedule their local
  // Spotify SDK `.play()` call at exactly the same instant.

  socket.on("play_command", ({ roomCode, spotifyUri, positionMs, targetTimestamp }) => {
    if (!validateHostCommand(socket, roomCode, "play_command")) return;

    const payload = { roomCode, spotifyUri, positionMs, targetTimestamp };

    // Broadcast to ALL clients in the room (including sender)
    io.in(roomCode).emit("execute_play", payload);

    console.log(
      `▶️  play_command in room ${roomCode} — uri: ${spotifyUri}, pos: ${positionMs}ms, target: ${targetTimestamp}`
    );
  });

  // ── pause_command ────────────────────────────────────────────────────────

  socket.on("pause_command", ({ roomCode, targetTimestamp }) => {
    if (!validateHostCommand(socket, roomCode, "pause_command")) return;

    const payload = { roomCode, targetTimestamp };
    io.in(roomCode).emit("execute_pause", payload);

    console.log(
      `⏸️  pause_command in room ${roomCode}, target: ${targetTimestamp}`
    );
  });

  // ── seek_command ─────────────────────────────────────────────────────────

  socket.on("seek_command", ({ roomCode, positionMs, targetTimestamp }) => {
    if (!validateHostCommand(socket, roomCode, "seek_command")) return;

    const payload = { roomCode, positionMs, targetTimestamp };
    io.in(roomCode).emit("execute_seek", payload);

    console.log(
      `⏩ seek_command in room ${roomCode} — pos: ${positionMs}ms, target: ${targetTimestamp}`
    );
  });

  // ── skip_command ─────────────────────────────────────────────────────────

  socket.on("skip_command", ({ roomCode, spotifyUri, targetTimestamp }) => {
    if (!validateHostCommand(socket, roomCode, "skip_command")) return;

    const payload = { roomCode, spotifyUri, targetTimestamp };
    io.in(roomCode).emit("execute_skip", payload);

    console.log(
      `⏭️  skip_command in room ${roomCode} — uri: ${spotifyUri}, target: ${targetTimestamp}`
    );
  });

  // ── ntp_ping (Clock Synchronization) ─────────────────────────────────────
  //
  // Each client periodically pings the server to measure round-trip time.
  // The server echoes back clientSendTime plus the current server time so
  // the client can compute:
  //   offset = serverTime - (clientSendTime + RTT/2)

  socket.on("ntp_ping", ({ clientSendTime }) => {
    socket.emit("ntp_pong", {
      clientSendTime,
      serverTime: Date.now(),
    });
  });

  // ── disconnect ───────────────────────────────────────────────────────────

  socket.on("disconnect", (reason) => {
    console.log(`❌ Client disconnected: ${socket.id} (${reason})`);

    const roomCode = socketRooms.get(socket.id);
    if (roomCode) {
      removeFromRoom(socket, roomCode);
    }

    logRoomsSnapshot();
  });
});

// ─── Room Cleanup Helper ─────────────────────────────────────────────────────

/**
 * Remove a socket from its room and handle cascading cleanup:
 *   - Remove from Socket.IO room
 *   - Remove from in-memory members set
 *   - If the room is now empty, delete it entirely
 *   - If the departing socket was the host, notify remaining members
 *   - Notify remaining members of the departure
 */
function removeFromRoom(socket, roomCode) {
  socket.leave(roomCode);
  socketRooms.delete(socket.id);

  const room = rooms.get(roomCode);
  if (!room) return;

  room.members.delete(socket.id);

  if (room.members.size === 0) {
    // Room is empty — clean up
    rooms.delete(roomCode);
    console.log(`🗑️  Room ${roomCode} deleted (empty)`);
    return;
  }

  // Notify remaining members
  const wasHost = room.hostSocketId === socket.id;

  if (wasHost) {
    // Promote the first remaining member to host
    const newHostId = room.members.values().next().value;
    room.hostSocketId = newHostId;

    io.in(roomCode).emit("host_changed", {
      newHostId,
      memberCount: room.members.size,
    });

    console.log(
      `👑 Host left room ${roomCode}, new host: ${newHostId}`
    );
  }

  io.in(roomCode).emit("member_left", {
    memberId: socket.id,
    memberCount: room.members.size,
  });
}

// ─── Host Validation Helper ──────────────────────────────────────────────────

/**
 * Validates that a socket is the host of the given room before allowing
 * a playback command to be broadcast.
 *
 * Returns true if valid, false if the command should be rejected.
 */
function validateHostCommand(socket, roomCode, commandName) {
  if (!roomCode || !rooms.has(roomCode)) {
    socket.emit("error_message", {
      message: `Room ${roomCode} does not exist.`,
    });
    console.log(
      `❌ ${commandName} rejected — room ${roomCode} does not exist (socket: ${socket.id})`
    );
    return false;
  }

  const room = rooms.get(roomCode);

  if (room.hostSocketId !== socket.id) {
    socket.emit("error_message", {
      message: "Only the host can send playback commands.",
    });
    console.log(
      `❌ ${commandName} rejected — socket ${socket.id} is not host of room ${roomCode}`
    );
    return false;
  }

  return true;
}

// ─── Health Check Endpoint ───────────────────────────────────────────────────

app.get("/", (_req, res) => {
  res.json({
    status: "ok",
    uptime: process.uptime(),
    rooms: rooms.size,
    timestamp: Date.now(),
  });
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: Date.now() });
});

// ─── Start Server ────────────────────────────────────────────────────────────

const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
  console.log("");
  console.log("══════════════════════════════════════════════════");
  console.log("🎵  Music Sync Server");
  console.log(`🚀  Listening on port ${PORT}`);
  console.log(`🕐  Server time: ${new Date().toISOString()}`);
  console.log("══════════════════════════════════════════════════");
  console.log("");
});
