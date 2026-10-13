import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

/// Mesh WebRTC voice chat. Socket.IO only relays SDP/ICE; it never receives audio.
class VoiceService {
  VoiceService(this._socket);
  final SocketService _socket;
  final Map<String, RTCPeerConnection> _peers = {};
  MediaStream? _localStream;
  bool _muted = false;
  bool get muted => _muted;

  Future<void> start(Iterable<String> peerIds) async {
    _localStream ??= await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    for (final peerId in peerIds) { await _offer(peerId); }
  }

  Future<void> _offer(String peerId) async {
    if (_peers.containsKey(peerId)) return;
    final pc = await _peer(peerId);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _socket.sendWebRtcSignal(peerId, {'type': 'offer', 'sdp': offer.sdp});
  }

  Future<RTCPeerConnection> _peer(String peerId) async {
    final existing = _peers[peerId]; if (existing != null) return existing;
    final pc = await createPeerConnection({'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]});
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) { await pc.addTrack(track, _localStream!); }
    pc.onIceCandidate = (candidate) { if (candidate.candidate != null) _socket.sendWebRtcSignal(peerId, {'type': 'ice', 'candidate': candidate.toMap()}); };
    _peers[peerId] = pc; return pc;
  }

  Future<void> handleSignal(String fromUserId, Map<String, dynamic> signal) async {
    _localStream ??= await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    final pc = await _peer(fromUserId); final type = signal['type'];
    if (type == 'offer') { await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'] as String?, 'offer')); final answer = await pc.createAnswer(); await pc.setLocalDescription(answer); _socket.sendWebRtcSignal(fromUserId, {'type': 'answer', 'sdp': answer.sdp}); }
    if (type == 'answer') await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'] as String?, 'answer'));
    if (type == 'ice' && signal['candidate'] is Map) { final c = Map<String, dynamic>.from(signal['candidate'] as Map); await pc.addCandidate(RTCIceCandidate(c['candidate'] as String?, c['sdpMid'] as String?, c['sdpMLineIndex'] as int?)); }
  }
  void setMuted(bool value) { _muted = value; for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) { track.enabled = !value; } }
  Future<void> dispose() async { for (final peer in _peers.values) { await peer.close(); } _peers.clear(); for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) { track.stop(); } await _localStream?.dispose(); _localStream = null; }
}
