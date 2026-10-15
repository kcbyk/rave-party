const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: process.env.CORS_ORIGIN || '*', methods: ['GET', 'POST'] } });
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '64kb' }));
const PORT = Number(process.env.PORT || 3000);
const storePath = process.env.DATA_FILE || path.join(__dirname, 'data', 'party-rave.json');
fs.mkdirSync(path.dirname(storePath), { recursive: true });

function load() { try { const d = JSON.parse(fs.readFileSync(storePath, 'utf8')); return { users: d.users || {}, friends: d.friends || {}, invitations: d.invitations || {}, rooms: d.rooms || {} }; } catch (_) { return { users: {}, friends: {}, invitations: {}, rooms: {} }; } }
const db = load();
const save = () => fs.writeFileSync(storePath, JSON.stringify(db, null, 2));
const newId = prefix => `${prefix}_${crypto.randomBytes(12).toString('hex')}`;
const userView = u => ({ id: u.id, name: u.name, avatarUrl: u.avatarUrl || '', bio: u.bio || '', isOnline: !!u.socketId, isMicOn: u.isMicOn !== false, isSpeaking: !!u.isSpeaking, currentWatching: u.currentWatching || null });
const getUser = (id, res) => { const u = db.users[id]; if (!u) res.status(404).json({ error: 'Kullanıcı bulunamadı' }); return u; };
const roomView = r => ({ id: r.id, hostId: r.hostId, title: r.title, movie: r.movie, playback: r.playback, participants: r.participants.map(id => db.users[id]).filter(Boolean).map(userView) });
const emitFriends = id => io.to(`user:${id}`).emit('friends_changed');

app.get('/api/health', (_, res) => res.json({ status: 'ok', activeUsers: Object.values(db.users).filter(u => u.socketId).length, activeRooms: Object.keys(db.rooms).length, timestamp: new Date().toISOString() }));
app.post('/api/users/sync', (req, res) => {
  const { id, name, avatarUrl, bio, isMicOn } = req.body || {};
  if (!id || !name) return res.status(400).json({ error: 'id and name are required' });
  const old = db.users[id] || {}; db.users[id] = { ...old, id, name: String(name).slice(0, 80), avatarUrl: avatarUrl || old.avatarUrl || '', bio: bio ?? old.bio ?? '', isMicOn: isMicOn ?? old.isMicOn ?? true, updatedAt: Date.now() }; db.friends[id] ||= []; save();
  res.json({ success: true, user: userView(db.users[id]) });
});
app.get('/api/users/search', (req, res) => { const q = String(req.query.q || '').trim().toLowerCase().replace('#', ''); res.json({ results: q ? Object.values(db.users).filter(u => u.id.toLowerCase().includes(q) || u.name.toLowerCase().includes(q)).slice(0, 20).map(userView) : [] }); });
app.get('/api/friends/:id', (req, res) => res.json({ friends: (db.friends[req.params.id] || []).map(id => db.users[id]).filter(Boolean).map(userView) }));
app.get('/api/invitations/:id', (req, res) => res.json({ invitations: Object.values(db.invitations).filter(i => i.toUserId === req.params.id && i.status === 'pending') }));
app.post('/api/friends/request', (req, res) => {
  const { userId, targetId } = req.body || {}; if (!getUser(userId, res) || !getUser(targetId, res)) return; if (userId === targetId) return res.status(400).json({ error: 'Kendinizi ekleyemezsiniz' }); if ((db.friends[userId] || []).includes(targetId)) return res.status(409).json({ error: 'Zaten arkadaşsınız' });
  let invite = Object.values(db.invitations).find(i => i.type === 'friend' && i.fromUserId === userId && i.toUserId === targetId && i.status === 'pending'); if (!invite) { invite = { id: newId('invite'), type: 'friend', fromUserId: userId, toUserId: targetId, status: 'pending', createdAt: Date.now() }; db.invitations[invite.id] = invite; save(); io.to(`user:${targetId}`).emit('invitation_received', invite); } res.status(201).json({ success: true, invitation: invite });
});
app.post('/api/invitations/:id/respond', (req, res) => {
  const invite = db.invitations[req.params.id]; const { userId, accept } = req.body || {}; if (!invite || invite.toUserId !== userId || invite.status !== 'pending') return res.status(404).json({ error: 'Geçerli davet bulunamadı' }); invite.status = accept === true ? 'accepted' : 'declined'; invite.respondedAt = Date.now();
  if (invite.status === 'accepted' && invite.type === 'friend') { db.friends[invite.fromUserId] ||= []; db.friends[invite.toUserId] ||= []; if (!db.friends[invite.fromUserId].includes(invite.toUserId)) db.friends[invite.fromUserId].push(invite.toUserId); if (!db.friends[invite.toUserId].includes(invite.fromUserId)) db.friends[invite.toUserId].push(invite.fromUserId); emitFriends(invite.fromUserId); emitFriends(invite.toUserId); }
  save(); io.to(`user:${invite.fromUserId}`).emit('invitation_responded', invite); res.json({ success: true, invitation: invite });
});
app.post('/api/rooms/create', (req, res) => { const { hostUserId, movie, title } = req.body || {}; if (!getUser(hostUserId, res)) return; const r = { id: newId('room'), hostId: hostUserId, title: title || movie?.title || 'Watch Party', movie: movie || null, participants: [hostUserId], playback: { isPlaying: false, currentSeconds: 0, updatedAt: Date.now() }, createdAt: Date.now() }; db.rooms[r.id] = r; save(); res.status(201).json({ success: true, room: roomView(r) }); });
app.get('/api/rooms/:id', (req, res) => { const r = db.rooms[req.params.id]; if (!r) return res.status(404).json({ error: 'Oda bulunamadı' }); res.json({ room: roomView(r) }); });
app.post('/api/rooms/:id/invite', (req, res) => { const r = db.rooms[req.params.id]; const { userId, targetId } = req.body || {}; if (!r) return res.status(404).json({ error: 'Oda bulunamadı' }); if (r.hostId !== userId) return res.status(403).json({ error: 'Sadece oda sahibi davet edebilir' }); if (!getUser(targetId, res)) return; if (!(db.friends[userId] || []).includes(targetId)) return res.status(403).json({ error: 'Yalnızca arkadaşlar davet edilebilir' }); const invite = { id: newId('invite'), type: 'room', roomId: r.id, fromUserId: userId, toUserId: targetId, status: 'pending', createdAt: Date.now() }; db.invitations[invite.id] = invite; save(); io.to(`user:${targetId}`).emit('invitation_received', invite); res.status(201).json({ success: true, invitation: invite }); });

io.on('connection', socket => {
  let userId; let roomId;
  socket.on('identify', ({ userId: supplied }) => { if (!db.users[supplied]) return socket.emit('app_error', { message: 'Önce profilinizi senkronize edin.' }); userId = supplied; db.users[userId].socketId = socket.id; save(); socket.join(`user:${userId}`); socket.emit('identified', { user: userView(db.users[userId]) }); });
  socket.on('join_room', ({ roomId: wanted }) => { const r = db.rooms[wanted]; if (!userId || !r) return socket.emit('app_error', { message: 'Oda veya kullanıcı bulunamadı.' }); const accepted = Object.values(db.invitations).some(i => i.type === 'room' && i.roomId === r.id && i.toUserId === userId && i.status === 'accepted'); if (r.hostId !== userId && !r.participants.includes(userId) && !accepted) return socket.emit('app_error', { message: 'Bu özel odaya davetli değilsiniz.' }); roomId = r.id; socket.join(roomId); if (!r.participants.includes(userId)) r.participants.push(userId); save(); socket.emit('room_state', roomView(r)); socket.to(roomId).emit('room_user_joined', { user: userView(db.users[userId]), participants: roomView(r).participants }); });
  socket.on('video_sync', data => { const r = db.rooms[roomId]; const action = data?.action; const time = Number(data?.time); if (!r || !['play', 'pause', 'seek'].includes(action) || !Number.isFinite(time)) return; r.playback = { isPlaying: action === 'play' ? true : action === 'pause' ? false : r.playback.isPlaying, currentSeconds: Math.max(0, time), updatedAt: Date.now() }; save(); socket.to(roomId).emit('video_sync', { action, time: r.playback.currentSeconds, isPlaying: r.playback.isPlaying, senderId: userId, serverTime: Date.now() }); });
  socket.on('chat_message', ({ message }) => { if (roomId && message && typeof message.content === 'string') io.to(roomId).emit('chat_message', { ...message, senderId: userId }); });
  socket.on('mic_status', ({ isMicOn, isSpeaking }) => { if (!roomId || !userId) return; db.users[userId].isMicOn = !!isMicOn; db.users[userId].isSpeaking = !!isSpeaking; save(); socket.to(roomId).emit('mic_status_changed', { userId, isMicOn: !!isMicOn, isSpeaking: !!isSpeaking }); });
  socket.on('webrtc_signal', ({ toUserId, signal }) => { const r = db.rooms[roomId]; if (r && toUserId && signal && r.participants.includes(toUserId)) io.to(`user:${toUserId}`).emit('webrtc_signal', { fromUserId: userId, signal }); });
  const leave = () => { if (!roomId || !userId) return; const r = db.rooms[roomId]; socket.leave(roomId); if (r) { r.participants = r.participants.filter(id => id !== userId); save(); socket.to(roomId).emit('room_user_left', { userId, participants: roomView(r).participants }); } roomId = null; };
  socket.on('leave_room', leave); socket.on('disconnect', () => { if (userId && db.users[userId]) { delete db.users[userId].socketId; db.users[userId].isSpeaking = false; save(); } leave(); });
});
server.listen(PORT, '0.0.0.0', () => console.log(`Party Rave API listening on ${PORT}`));
