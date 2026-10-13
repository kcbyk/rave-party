const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);

// CORS ve JSON Body Parser
app.use(cors({ origin: '*' }));
app.use(express.json());

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const PORT = process.env.PORT || 3000;

// ==========================================
// Bellek İçi Veri Depoları (Real Database / In-Memory)
// ==========================================
// users: userId -> { id, name, avatarUrl, bio, isOnline, isMicOn, isSpeaking, currentWatching, socketId }
const users = new Map();

// friendships: userId -> Set of friendUserIds
const friendships = new Map();

// rooms: roomId -> { id, hostId, title, movie, playback: { isPlaying, currentSeconds, lastUpdate }, participants: Map(userId -> user) }
const rooms = new Map();

// ==========================================
// REST API ENDPOINTS
// ==========================================

// Sağlık kontrolü
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    activeUsers: users.size,
    activeRooms: rooms.size,
    timestamp: new Date().toISOString()
  });
});

// 1. Kullanıcı Profili Kayıt / Senkronizasyon
app.post('/api/users/sync', (req, res) => {
  const { id, name, avatarUrl, bio, isMicOn } = req.body;
  if (!id || !name) {
    return res.status(400).json({ error: 'id and name are required' });
  }

  const existing = users.get(id) || {};
  const updatedUser = {
    ...existing,
    id,
    name,
    avatarUrl: avatarUrl || existing.avatarUrl || '',
    bio: bio !== undefined ? bio : (existing.bio || ''),
    isMicOn: isMicOn !== undefined ? isMicOn : true,
    isSpeaking: false,
    isOnline: true,
    lastSeen: Date.now()
  };

  users.set(id, updatedUser);

  // Arkadaşlık seti yoksa başlat
  if (!friendships.has(id)) {
    friendships.set(id, new Set());
  }

  console.log(`[USER SYNC] ${name} (#${id}) kaydedildi.`);
  res.json({ success: true, user: updatedUser });
});

// 2. Kullanıcı Arama (Klasik ID veya İsim ile)
app.get('/api/users/search', (req, res) => {
  const query = (req.query.q || '').trim().toLowerCase().replace('#', '');
  if (!query) {
    return res.json({ results: [] });
  }

  const results = [];
  for (const user of users.values()) {
    const idMatch = user.id.toLowerCase().includes(query);
    const nameMatch = user.name.toLowerCase().includes(query);
    if (idMatch || nameMatch) {
      results.push({
        id: user.id,
        name: user.name,
        avatarUrl: user.avatarUrl,
        bio: user.bio,
        isOnline: user.isOnline,
        currentWatching: user.currentWatching,
        isMicOn: user.isMicOn
      });
    }
  }

  res.json({ results });
});

// 3. Kullanıcı Bilgisi Getirme
app.get('/api/users/:id', (req, res) => {
  const user = users.get(req.params.id);
  if (!user) {
    return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
  }
  res.json({ user });
});

// 4. Arkadaş Listesi
app.get('/api/friends/:userId', (req, res) => {
  const { userId } = req.params;
  const friendIds = friendships.get(userId) || new Set();
  const friendProfiles = [];

  for (const fId of friendIds) {
    const profile = users.get(fId);
    if (profile) {
      friendProfiles.push({
        id: profile.id,
        name: profile.name,
        avatarUrl: profile.avatarUrl,
        bio: profile.bio,
        isOnline: profile.isOnline,
        currentWatching: profile.currentWatching,
        isMicOn: profile.isMicOn,
        isSpeaking: profile.isSpeaking
      });
    }
  }

  res.json({ friends: friendProfiles });
});

// 5. Arkadaş Ekle
app.post('/api/friends/add', (req, res) => {
  const { userId, targetId } = req.body;
  if (!userId || !targetId) {
    return res.status(400).json({ error: 'userId and targetId are required' });
  }
  if (userId === targetId) {
    return res.status(400).json({ error: 'Kendinizi arkadaş olarak ekleyemezsiniz' });
  }

  const targetUser = users.get(targetId);
  if (!targetUser) {
    return res.status(404).json({ error: 'Hedef kullanıcı bulunamadı' });
  }

  if (!friendships.has(userId)) friendships.set(userId, new Set());
  if (!friendships.has(targetId)) friendships.set(targetId, new Set());

  friendships.get(userId).add(targetId);
  friendships.get(targetId).add(userId);

  console.log(`[FRIEND] ${userId} ve ${targetId} arkadaş oldu.`);
  res.json({ success: true, targetUser });
});

// 6. Arkadaş Çıkar
app.post('/api/friends/remove', (req, res) => {
  const { userId, targetId } = req.body;
  if (!userId || !targetId) {
    return res.status(400).json({ error: 'userId and targetId are required' });
  }

  if (friendships.has(userId)) friendships.get(userId).delete(targetId);
  if (friendships.has(targetId)) friendships.get(targetId).delete(userId);

  res.json({ success: true });
});

// 7. Oda Oluşturma / Sorgulama
app.post('/api/rooms/create', (req, res) => {
  const { hostUser, movie } = req.body;
  if (!hostUser || !hostUser.id) {
    return res.status(400).json({ error: 'hostUser required' });
  }

  // 6 haneli benzersiz oda kodu
  const roomId = 'RAVE-' + Math.floor(1000 + Math.random() * 9000);

  const newRoom = {
    id: roomId,
    hostId: hostUser.id,
    title: movie ? movie.title : 'Watch Party',
    movie: movie || null,
    playback: {
      isPlaying: true,
      currentSeconds: 0.0,
      lastUpdate: Date.now()
    },
    participants: new Map([[hostUser.id, hostUser]]),
    createdAt: Date.now()
  };

  rooms.set(roomId, newRoom);
  console.log(`[ROOM CREATED] ${roomId} (Host: ${hostUser.name})`);

  res.json({
    success: true,
    roomId,
    room: {
      ...newRoom,
      participants: Array.from(newRoom.participants.values())
    }
  });
});

app.get('/api/rooms/:roomId', (req, res) => {
  const room = rooms.get(req.params.roomId);
  if (!room) {
    return res.status(404).json({ error: 'Oda bulunamadı' });
  }
  res.json({
    room: {
      ...room,
      participants: Array.from(room.participants.values())
    }
  });
});

// ==========================================
// SOCKET.IO REAL-TIME EVENT ENGINE
// ==========================================

io.on('connection', (socket) => {
  console.log(`[SOCKET CONNECT] Socket ID: ${socket.id}`);
  let currentRoomId = null;
  let currentUserId = null;

  // 1. Odaya Katılma
  socket.on('join_room', (data) => {
    const { roomId, user } = data;
    if (!roomId || !user || !user.id) return;

    currentRoomId = roomId;
    currentUserId = user.id;
    socket.join(roomId);

    // Kullanıcıyı güncelle
    users.set(user.id, {
      ...(users.get(user.id) || {}),
      ...user,
      isOnline: true,
      socketId: socket.id
    });

    // Odayı bul veya oluştur
    let room = rooms.get(roomId);
    if (!room) {
      room = {
        id: roomId,
        hostId: user.id,
        title: 'Watch Party',
        movie: null,
        playback: {
          isPlaying: true,
          currentSeconds: 0.0,
          lastUpdate: Date.now()
        },
        participants: new Map(),
        createdAt: Date.now()
      };
      rooms.set(roomId, room);
    }

    room.participants.set(user.id, user);

    const participantsList = Array.from(room.participants.values());

    console.log(`[ROOM JOIN] ${user.name} (#${user.id}) -> Oda: ${roomId} (Toplam: ${participantsList.length})`);

    // Katılan kullanıcıya güncel oda durumunu gönder
    socket.emit('room_state', {
      roomId,
      playback: room.playback,
      movie: room.movie,
      participants: participantsList
    });

    // Odadaki diğer herkese yeni katılımcıyı duyur
    socket.to(roomId).emit('room_user_joined', {
      user,
      participants: participantsList
    });
  });

  // 2. Video Senkronizasyonu (Play, Pause, Seek)
  socket.on('video_sync', (data) => {
    const { roomId, action, time, senderId } = data;
    const room = rooms.get(roomId);
    if (!room) return;

    if (action === 'play') {
      room.playback.isPlaying = true;
      room.playback.currentSeconds = time !== undefined ? time : room.playback.currentSeconds;
      room.playback.lastUpdate = Date.now();
    } else if (action === 'pause') {
      room.playback.isPlaying = false;
      room.playback.currentSeconds = time !== undefined ? time : room.playback.currentSeconds;
      room.playback.lastUpdate = Date.now();
    } else if (action === 'seek') {
      room.playback.currentSeconds = time;
      room.playback.lastUpdate = Date.now();
    }

    console.log(`[VIDEO SYNC] Oda: ${roomId} | Action: ${action} | Time: ${time}s | Gönderen: ${senderId}`);

    // Gönderen dışındaki herkese anında senkron sinyali yayınla
    socket.to(roomId).emit('video_sync', {
      action,
      time: room.playback.currentSeconds,
      isPlaying: room.playback.isPlaying,
      senderId
    });
  });

  // 3. Medya / Film Değişimi
  socket.on('media_change', (data) => {
    const { roomId, movie, senderId } = data;
    const room = rooms.get(roomId);
    if (!room) return;

    room.movie = movie;
    room.playback.currentSeconds = 0.0;
    room.playback.isPlaying = true;
    room.playback.lastUpdate = Date.now();

    console.log(`[MEDIA CHANGE] Oda: ${roomId} | Film: ${movie?.title}`);
    socket.to(roomId).emit('media_change', { movie, senderId });
  });

  // 4. Canlı Sohbet Mesajı
  socket.on('chat_message', (data) => {
    const { roomId, message } = data;
    if (!roomId || !message) return;

    console.log(`[CHAT] Oda: ${roomId} | ${message.userName}: ${message.text}`);
    // Odadaki herkese (gönderen dahil veya diğerlerine) ilet
    io.in(roomId).emit('chat_message', message);
  });

  // 5. Ekranda Uçuşan Tepkiler (Reactions)
  socket.on('send_reaction', (data) => {
    const { roomId, emoji, senderId } = data;
    if (!roomId) return;

    socket.to(roomId).emit('reaction_received', { emoji, senderId });
  });

  // 6. Mikrofon ve Ses Konuşma Durumu
  socket.on('mic_status', (data) => {
    const { roomId, userId, isMicOn, isSpeaking } = data;
    const room = rooms.get(roomId);
    if (room && room.participants.has(userId)) {
      const p = room.participants.get(userId);
      if (isMicOn !== undefined) p.isMicOn = isMicOn;
      if (isSpeaking !== undefined) p.isSpeaking = isSpeaking;
    }

    socket.to(roomId).emit('mic_status_changed', {
      userId,
      isMicOn,
      isSpeaking
    });
  });

  // 7. Web Gezintisi Senkronizasyonu (Google Web)
  socket.on('web_sync', (data) => {
    const { roomId, action, payload, senderId } = data;
    if (!roomId) return;

    // 'tab_change', 'search', 'scroll'
    socket.to(roomId).emit('web_sync', {
      action,
      payload,
      senderId
    });
  });

  // 8. Odadan Ayrılma
  socket.on('leave_room', (data) => {
    const { roomId, userId } = data;
    handleLeaveRoom(roomId, userId);
  });

  // 9. Bağlantı Kopması
  socket.on('disconnect', () => {
    console.log(`[SOCKET DISCONNECT] Socket ID: ${socket.id}`);
    if (currentRoomId && currentUserId) {
      handleLeaveRoom(currentRoomId, currentUserId);
    }
  });

  function handleLeaveRoom(rId, uId) {
    if (!rId || !uId) return;
    const room = rooms.get(rId);
    if (!room) return;

    room.participants.delete(uId);
    socket.leave(rId);

    const remaining = Array.from(room.participants.values());
    console.log(`[ROOM LEAVE] ${uId} ayrıldı -> Oda: ${rId} (Kalan: ${remaining.length})`);

    socket.to(rId).emit('room_user_left', {
      userId: uId,
      participants: remaining
    });

    if (remaining.length === 0) {
      // 5 dakika sonra odayı temizleme zamanlayıcısı eklenebilir
      console.log(`[ROOM EMPTY] Oda ${rId} boşaldı.`);
    }
  }
});

// Sunucuyu Başlat
server.listen(PORT, '0.0.0.0', () => {
  console.log(`=============================================`);
  console.log(`🚀 Party Rave Backend Server Çalışıyor!`);
  console.log(`📡 HTTP: http://localhost:${PORT}`);
  console.log(`⚡ WebSocket (Socket.IO): ws://localhost:${PORT}`);
  console.log(`=============================================`);
});
