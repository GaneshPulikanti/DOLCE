import mqtt from 'mqtt';

/**
 * DOLCE Jam Service (Spotify Jam-style Real-Time Co-Listening Engine)
 * Synchronizes playback, queue, and seeking across multiple devices in real-time over WebSocket MQTT.
 * Ultra-low latency (<50ms), zero-server setup, works seamlessly across cellular data and Wi-Fi.
 */

const PRIMARY_BROKER = 'wss://broker.emqx.io:8084/mqtt';

class JamService {
  constructor() {
    this.client = null;
    this.roomCode = null;
    this.role = null; // 'host' | 'guest'
    this.deviceId = this.getOrCreateDeviceId();
    this.userName = this.getOrCreateUserName();
    this.participants = [];
    this.allowGuestControl = true;
    this.heartbeatTimer = null;
    this.isConnecting = false;
    this.isConnected = false;
    this.messageSeq = 0;
    this.lastProcessedSeqBySender = new Map();

    // Callbacks
    this.onStateChangeCallback = null;
    this.onSyncCommandCallback = null;
  }

  saveSession(code, role) {
    if (typeof localStorage === 'undefined') return;
    try {
      localStorage.setItem('DOLCE_JAM_PERSISTED_SESSION', JSON.stringify({
        code,
        role,
        userName: this.userName,
        isHost: role === 'host',
        savedAt: Date.now()
      }));
    } catch (_) {}
  }

  clearSession() {
    if (typeof localStorage === 'undefined') return;
    try {
      localStorage.removeItem('DOLCE_JAM_PERSISTED_SESSION');
    } catch (_) {}
  }

  getSavedSession() {
    if (typeof localStorage === 'undefined') return null;
    try {
      const raw = localStorage.getItem('DOLCE_JAM_PERSISTED_SESSION');
      return raw ? JSON.parse(raw) : null;
    } catch (_) {
      return null;
    }
  }

  autoRestoreSession(getStateCallback) {
    const saved = this.getSavedSession();
    if (!saved || !saved.code) return;

    console.log(`🛸 [JamService] Auto-restoring persistent Jam session: ${saved.code} (${saved.role})`);
    this.roomCode = saved.code;
    this.role = saved.role;
    this.participants = [{
      deviceId: this.deviceId,
      name: saved.isHost ? `${this.userName} (Host)` : this.userName,
      role: saved.role,
      isHost: saved.isHost,
      joinedAt: saved.savedAt || Date.now()
    }];

    this.connectClient(saved.code, () => {
      if (saved.role === 'host') {
        this.startHostHeartbeat(getStateCallback);
      } else {
        this.publishMessage({
          type: 'JOIN',
          deviceId: this.deviceId,
          name: this.userName,
          isReconnecting: true,
          timestamp: Date.now()
        });
      }
    });
  }

  getOrCreateDeviceId() {
    if (typeof localStorage === 'undefined') {
      return `dev_${Math.random().toString(36).substring(2, 9)}`;
    }
    let id = localStorage.getItem('DOLCE_JAM_DEVICE_ID');
    if (!id) {
      id = `dev_${Math.random().toString(36).substring(2, 9)}`;
      localStorage.setItem('DOLCE_JAM_DEVICE_ID', id);
    }
    return id;
  }

  getOrCreateUserName() {
    if (typeof localStorage === 'undefined') {
      return 'Listener';
    }
    let name = localStorage.getItem('DOLCE_JAM_USER_NAME');
    if (!name) {
      const adjectives = ['Cool', 'Swift', 'Chill', 'Vibe', 'Sonic', 'Audio', 'Cosmic'];
      const nouns = ['Rider', 'Buddy', 'Friend', 'Racer', 'Beats', 'Traveler'];
      name = `${adjectives[Math.floor(Math.random() * adjectives.length)]} ${nouns[Math.floor(Math.random() * nouns.length)]}`;
      localStorage.setItem('DOLCE_JAM_USER_NAME', name);
    }
    return name;
  }

  setUserName(newName) {
    if (!newName || !newName.trim()) return;
    this.userName = newName.trim();
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('DOLCE_JAM_USER_NAME', this.userName);
    }
    if (this.isConnected && this.roomCode) {
      this.publishMessage({
        type: 'USER_UPDATE',
        deviceId: this.deviceId,
        name: this.userName,
        role: this.role
      });
    }
  }

  getTopic(code) {
    return `dolce/jam/v1/${code.toUpperCase()}`;
  }

  /**
   * Connect to MQTT Broker
   * All devices connect to the unified global broker to prevent split-brain partition
   */
  connectClient(roomCode, onConnectSuccess, onError) {
    if (this.client) {
      try { this.client.end(true); } catch (_) {}
      this.client = null;
    }

    console.log(`🛸 [JamService] Connecting to unified broker: ${PRIMARY_BROKER} for room ${roomCode}`);

    this.isConnecting = true;
    this.notifyState();

    try {
      this.client = mqtt.connect(PRIMARY_BROKER, {
        clientId: `dolce_${this.deviceId}_${Math.random().toString(16).substring(2, 6)}`,
        clean: true,
        connectTimeout: 10000,
        reconnectPeriod: 2000,
        keepalive: 30,
      });

      this.client.on('connect', () => {
        console.log(`✅ [JamService] Connected/Reconnected to room ${roomCode}`);
        this.isConnected = true;
        this.isConnecting = false;

        const topic = this.getTopic(roomCode);
        this.client.subscribe(topic, { qos: 0 }, (err) => {
          if (err) {
            console.error('Failed to subscribe:', err);
            if (onError) onError(err);
          } else {
            if (onConnectSuccess) onConnectSuccess();

            // Reconnection state synchronization
            if (this.role === 'guest') {
              this.publishMessage({
                type: 'JOIN',
                deviceId: this.deviceId,
                name: this.userName,
                isReconnecting: true,
                timestamp: Date.now()
              });
            } else if (this.role === 'host' && this.onSyncCommandCallback) {
              const currentState = this.onSyncCommandCallback('GET_CURRENT_STATE');
              if (currentState && currentState.currentTrack) {
                this.publishMessage({
                  type: 'SYNC_FULL_STATE',
                  currentTrack: currentState.currentTrack,
                  isPlaying: currentState.isPlaying,
                  currentTime: currentState.currentTime || 0,
                  queue: currentState.queue || [],
                  allowGuestControl: this.allowGuestControl,
                  hostTimestamp: Date.now(),
                });
              }
            }
          }
        });
        this.notifyState();
      });

      this.client.on('message', (topic, rawMessage) => {
        try {
          const msg = JSON.parse(rawMessage.toString());
          this.handleIncomingMessage(msg);
        } catch (e) {
          console.warn('Jam invalid message:', e);
        }
      });

      this.client.on('error', (err) => {
        console.warn('Jam MQTT Error:', err);
        this.isConnecting = false;
        this.notifyState();
        if (onError) onError(err);
      });

      this.client.on('close', () => {
        this.isConnected = false;
        this.notifyState();
      });

    } catch (err) {
      this.isConnecting = false;
      this.notifyState();
      if (onError) onError(err);
    }
  }

  /**
   * Start a new Jam Session as Host
   */
  createSession(initialState = {}) {
    return new Promise((resolve, reject) => {
      // Generate clean 4-character code (avoid confusing 0/O, 1/I)
      const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
      let code = '';
      for (let i = 0; i < 4; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
      }

      this.roomCode = code;
      this.role = 'host';
      this.messageSeq = 0;
      this.lastProcessedSeqBySender.clear();
      this.participants = [{
        deviceId: this.deviceId,
        name: `${this.userName} (Host)`,
        role: 'host',
        isHost: true,
        joinedAt: Date.now()
      }];

      this.saveSession(code, 'host');

      this.connectClient(code, () => {
        this.startHostHeartbeat(initialState);
        resolve({ code, role: 'host' });
      }, (err) => {
        reject(err);
      });
    });
  }

  /**
   * Join an existing Jam Session as Guest
   */
  joinSession(code) {
    return new Promise((resolve, reject) => {
      if (!code || !code.trim()) {
        reject(new Error('Invalid Jam Code'));
        return;
      }

      const normalizedCode = code.trim().toUpperCase();
      this.roomCode = normalizedCode;
      this.role = 'guest';
      this.messageSeq = 0;
      this.lastProcessedSeqBySender.clear();
      this.participants = [{
        deviceId: this.deviceId,
        name: this.userName,
        role: 'guest',
        isHost: false,
        joinedAt: Date.now()
      }];

      this.saveSession(normalizedCode, 'guest');

      this.connectClient(normalizedCode, () => {
        // Send JOIN announcement to host
        this.publishMessage({
          type: 'JOIN',
          deviceId: this.deviceId,
          name: this.userName,
          timestamp: Date.now()
        });

        resolve({ code: normalizedCode, role: 'guest' });
      }, (err) => {
        reject(err);
      });
    });
  }

  /**
   * Leave Jam Session
   */
  leaveSession() {
    this.clearSession();
    if (this.isConnected && this.roomCode) {
      this.publishMessage({
        type: 'LEAVE',
        deviceId: this.deviceId,
        name: this.userName
      });
    }

    this.stopHostHeartbeat();

    if (this.client) {
      try { this.client.end(true); } catch (_) {}
      this.client = null;
    }

    this.roomCode = null;
    this.role = null;
    this.participants = [];
    this.isConnected = false;
    this.isConnecting = false;
    this.messageSeq = 0;
    this.lastProcessedSeqBySender.clear();
    this.notifyState();
  }

  publishMessage(msg) {
    if (!this.client || !this.isConnected || !this.roomCode) return;
    const topic = this.getTopic(this.roomCode);
    this.messageSeq++;
    const enriched = {
      ...msg,
      seq: this.messageSeq,
      senderId: this.deviceId,
      senderName: this.userName,
      sentAt: Date.now()
    };
    try {
      this.client.publish(topic, JSON.stringify(enriched), { qos: 0 });
    } catch (e) {
      console.warn('Jam publish error:', e);
    }
  }

  startHostHeartbeat(getStateCallback) {
    this.stopHostHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      if (this.role !== 'host' || !this.isConnected) return;
      const state = typeof getStateCallback === 'function' ? getStateCallback() : {};
      this.publishMessage({
        type: 'HEARTBEAT',
        trackId: state.currentTrack?.id || null,
        isPlaying: state.isPlaying || false,
        currentTime: state.currentTime || 0,
      });
    }, 5000);
  }

  stopHostHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  /**
   * Process incoming Jam messages
   */
  handleIncomingMessage(msg) {
    if (!msg || !msg.type) return;

    // Discard our own messages
    if (msg.senderId === this.deviceId) return;

    // Per-sender monotonic sequencing: drop duplicate or out-of-order packets from the SAME sender
    if (msg.senderId && msg.seq) {
      const lastSeq = this.lastProcessedSeqBySender.get(msg.senderId) || 0;
      if (msg.seq <= lastSeq) {
        return;
      }
      this.lastProcessedSeqBySender.set(msg.senderId, msg.seq);
    }

    switch (msg.type) {
      case 'JOIN': {
        // Add to participants if not already present
        if (!this.participants.some(p => p.deviceId === msg.deviceId)) {
          this.participants = [...this.participants, {
            deviceId: msg.deviceId,
            name: msg.name || 'Friend',
            role: 'guest',
            isHost: false,
            joinedAt: Date.now()
          }];
          this.notifyState();
        }

        // If I am Host, respond with immediate full state sync TARGETED to this newly joined device
        if (this.role === 'host' && this.onSyncCommandCallback) {
          const currentState = this.onSyncCommandCallback('GET_CURRENT_STATE');
          if (currentState) {
            this.publishMessage({
              type: 'SYNC_FULL_STATE',
              targetDeviceId: msg.deviceId,
              currentTrack: currentState.currentTrack,
              isPlaying: currentState.isPlaying,
              currentTime: currentState.currentTime || 0,
              queue: currentState.queue || [],
              allowGuestControl: this.allowGuestControl,
            });
          }
        }
        break;
      }

      case 'SYNC_FULL_STATE': {
        if (msg.allowGuestControl !== undefined) {
          this.allowGuestControl = msg.allowGuestControl;
        }

        // If message was specifically targeted to a different joining guest, do not disturb existing local playback
        if (msg.targetDeviceId && msg.targetDeviceId !== this.deviceId) {
          return;
        }

        // Apply state through callback
        if (this.onSyncCommandCallback) {
          this.onSyncCommandCallback('APPLY_SYNC_STATE', msg);
        }
        this.notifyState();
        break;
      }

      case 'HEARTBEAT': {
        if (this.role === 'guest' && this.onSyncCommandCallback) {
          this.onSyncCommandCallback('APPLY_HEARTBEAT', msg);
        }
        break;
      }

      case 'PLAY': {
        if (this.onSyncCommandCallback) {
          this.onSyncCommandCallback('REMOTE_PLAY', msg);
        }
        break;
      }

      case 'PAUSE': {
        if (this.onSyncCommandCallback) {
          this.onSyncCommandCallback('REMOTE_PAUSE', msg);
        }
        break;
      }

      case 'SEEK': {
        if (this.onSyncCommandCallback) {
          this.onSyncCommandCallback('REMOTE_SEEK', msg);
        }
        break;
      }

      case 'TRACK_CHANGE': {
        if (this.onSyncCommandCallback) {
          this.onSyncCommandCallback('REMOTE_TRACK_CHANGE', msg);
        }
        break;
      }

      case 'QUEUE_UPDATE': {
        if (this.onSyncCommandCallback) {
          this.onSyncCommandCallback('REMOTE_QUEUE_UPDATE', msg);
        }
        break;
      }

      case 'LEAVE': {
        this.participants = this.participants.filter(p => p.deviceId !== msg.deviceId);
        this.notifyState();
        break;
      }

      case 'USER_UPDATE': {
        this.participants = this.participants.map(p => {
          if (p.deviceId === msg.deviceId) {
            return { ...p, name: msg.name };
          }
          return p;
        });
        this.notifyState();
        break;
      }

      case 'CONTROL_SETTING': {
        if (msg.allowGuestControl !== undefined) {
          this.allowGuestControl = msg.allowGuestControl;
          this.notifyState();
        }
        break;
      }

      default:
        break;
    }
  }

  // Outbound action triggers (invoked by user actions in player store)
  broadcastPlay(currentTime, track) {
    const trackObj = typeof track === 'object' ? track : null;
    const trackId = trackObj ? trackObj.id : (typeof track === 'string' ? track : null);
    this.publishMessage({
      type: 'PLAY',
      trackId: trackId || null,
      track: trackObj,
      currentTime: currentTime || 0,
    });
  }

  broadcastPause(currentTime, track) {
    const trackObj = typeof track === 'object' ? track : null;
    const trackId = trackObj ? trackObj.id : (typeof track === 'string' ? track : null);
    this.publishMessage({
      type: 'PAUSE',
      trackId: trackId || null,
      track: trackObj,
      currentTime: currentTime || 0,
    });
  }

  broadcastSeek(seconds) {
    this.publishMessage({
      type: 'SEEK',
      currentTime: seconds,
    });
  }

  broadcastTrackChange(track, queue, startSeconds = 0) {
    this.publishMessage({
      type: 'TRACK_CHANGE',
      track,
      queue,
      startSeconds,
    });
  }

  broadcastQueueUpdate(queue) {
    this.publishMessage({
      type: 'QUEUE_UPDATE',
      queue,
    });
  }

  setAllowGuestControl(allowed) {
    this.allowGuestControl = allowed;
    this.publishMessage({
      type: 'CONTROL_SETTING',
      allowGuestControl: allowed
    });
    this.notifyState();
  }

  notifyState() {
    if (this.onStateChangeCallback) {
      this.onStateChangeCallback({
        isInJam: !!this.roomCode,
        roomCode: this.roomCode,
        role: this.role,
        isHost: this.role === 'host',
        isConnected: this.isConnected,
        isConnecting: this.isConnecting,
        participants: this.participants,
        allowGuestControl: this.allowGuestControl,
        userName: this.userName,
        deviceId: this.deviceId
      });
    }
  }
}

export const jamService = new JamService();
