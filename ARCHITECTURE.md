# Music Sync App Architecture (The Universal Remote)

## 1. System Overview
The Music Sync App is a **Universal Remote** system that synchronizes audio playback across multiple physical devices (phones/tablets). 

> **STRICT CONSTRAINT**: This app does **NOT** capture, stream, or relay raw PCM/MP3 audio data over the local network or internet. Audio playback is rendered locally on each phone via the native **Spotify App Remote SDK** (or local playback manager).

---

## 2. Core Components

```
 ┌────────────────────────────────────────────────────────────┐
 │                     Node.js Sync Server                    │
 │                                                            │
 │  - Socket.IO WebSocket Server                              │
 │  - NTP Clock Sync Server (Pings & Server Time Provider)    │
 │  - Room Management & Broadcast Hub                         │
 └─────────────┬──────────────────────────────▲───────────────┘
               │                              │
               │ Broadcast Commands           │ Commands & NTP Pings
               ▼                              │
 ┌─────────────────────────────┐  ┌───────────┴────────────────┐
 │     Host Phone (Flutter)    │  │    Member Phone (Flutter)  │
 │  - Room Creator & Controller│  │  - Synchronized Client     │
 │  - Master Clock Sync Engine │  │  - Master Clock Sync Engine│
 │  - 1.5s Buffer Calculation  │  │  - High-Precision Timer  │
 │  - Spotify App Remote SDK   │  │  - Spotify App Remote SDK │
 └─────────────────────────────┘  └────────────────────────────┘
```

### A. Node.js WebSocket Server
- Coordinates room lifecycle (create room, join room by 4-6 digit code, leave room).
- Responds to high-precision `ntp_ping` requests with `serverTimestamp = Date.now()`.
- Relays synchronized playback events (`sync_play`, `sync_pause`, `sync_seek`, `sync_track_change`) to all sockets in a room.

### B. Flutter App (`app/` folder)
- Provides a UI for Room Management (Home Screen) and Music Control (Player Screen).
- **Clock Synchronization Module**: Runs NTP round-trip ping/pong measurements against the server to determine clock offset $Offset = T_{\text{server}} - (T_{\text{local}} + \frac{\text{RTT}}{2})$.
- **Buffer & Timestamp Engine**: Calculates target execution time $T_{\text{target}} = T_{\text{server\_est}} + 1500\,\text{ms}$.
- **Spotify Remote Controller**: Interacts with `spotify_sdk` to start/stop playback, seek to precise milliseconds, and query track metadata.

---

## 3. Playback Synchronization Sequence

1. **Host Action**: Host taps Play / Pause / Seek / Skip.
2. **Buffer Calculation**: App calculates target server timestamp:
   $$T_{\text{target}} = T_{\text{local\_now}} + Offset_{\text{master}} + 1500\,\text{ms}$$
3. **Broadcast**: Host sends `{ roomCode, trackUri, positionMs, targetTimestamp }` to Node.js server.
4. **Distribution**: Node.js server broadcasts the command to all room members.
5. **Timed Execution**: Each client calculates:
   $$\text{delay} = T_{\text{target}} - (T_{\text{client\_now}} + Offset_{\text{master}})$$
   - If $\text{delay} > 0$: Schedule high-precision timer to fire in $\text{delay}$ milliseconds, then invoke Spotify SDK.
   - If $\text{delay} \le 0$: Client is lagging or joined late. Immediately seek to $\text{positionMs} + |\text{delay}|$ and play.

---

## 4. UI Design Guidelines
- **Modern Dark Aesthetic**: Deep HSL colors (#0F0F1A to #1A1A2E background), glassmorphism cards, glowing vibrant emerald/neon Spotify accents (`#1DB954`).
- **Smooth Micro-animations**: Album art glow effect, dynamic audio wave visualizer, pulsing sync status indicators, smooth transitions.
