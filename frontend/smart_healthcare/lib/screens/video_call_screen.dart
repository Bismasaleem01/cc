import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../services/auth_service.dart'; // Just to get baseUrl if needed
import '../services/video_service.dart';
import '../utils/jwt_storage.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final int? appointmentId;

  const VideoCallScreen({
    super.key,
    this.roomId = 'general',
    this.appointmentId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  WebSocketChannel? _channel;
  bool _inCall = false;
  bool _isStarting = false;
  String _role = 'patient';
  final List<Map<String, dynamic>> _pendingSignals = [];
  final List<Map<String, dynamic>> _pendingCandidates = [];
  bool _remoteReady = false;
  bool _hasRemoteDescription = false;
  bool _isMuted = false;
  String _statusMessage =
      'Tap Start Secure Video to allow camera and microphone.';

  @override
  void initState() {
    super.initState();
    _enterRoom();
  }

  Future<void> _enterRoom() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _loadRole();
      _connectSignalingServer();
      if (!mounted) return;
      setState(() {
        _statusMessage = _role == 'patient'
            ? 'Tap Start Secure Video. After you allow camera and microphone, the doctor will be notified.'
            : 'Tap Start Secure Video when you are ready to join the consultation.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Tap Start Secure Video. If no permission prompt appears, the browser does not trust this HTTPS certificate yet.';
      });
    }
  }

  Future<void> _loadRole() async {
    final profile = await AuthService.fetchProfile();
    _role = profile?['role'] ?? 'patient';
  }

  void _connectSignalingServer() async {
    try {
      await JwtStorage.getToken();
      final wsUrl = Uri.parse(
        '${AuthService.baseUrl.replaceFirst('http', 'ws')}/video/ws/video/${widget.roomId}',
      );
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          _handleSignalingMessage(data);
        },
        onError: (error) {
          if (!mounted || _inCall) return;
          setState(() {
            _statusMessage =
                'Video signaling is not connected yet. You can still tap Start Secure Video to test camera permission.';
          });
        },
      );
    } catch (e) {
      if (!mounted || _inCall) return;
      setState(() {
        _statusMessage =
            'Video signaling is not connected yet. You can still tap Start Secure Video to test camera permission.';
      });
    }
  }

  void _handleSignalingMessage(Map<String, dynamic> data) async {
    if (data['type'] == 'ready') {
      _remoteReady = true;
      if (_peerConnection == null) return;
      if (_role == 'patient') {
        await _sendOffer();
      }
      return;
    } else if (data['type'] == 'call-ended') {
      await _handleRemoteEnded();
      return;
    }

    if (_peerConnection == null) {
      _pendingSignals.add(data);
      return;
    }

    if (data['type'] == 'offer') {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
      _hasRemoteDescription = true;
      await _flushPendingCandidates();
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _channel!.sink.add(jsonEncode({'type': 'answer', 'sdp': answer.sdp}));
    } else if (data['type'] == 'answer') {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
      _hasRemoteDescription = true;
      await _flushPendingCandidates();
    } else if (data['type'] == 'candidate') {
      if (!_hasRemoteDescription) {
        _pendingCandidates.add(data);
        return;
      }
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ),
      );
    }
  }

  Future<void> _sendOffer() async {
    if (_peerConnection == null || _channel == null) return;
    final state = await _peerConnection!.getSignalingState();
    if (state != RTCSignalingState.RTCSignalingStateStable) return;
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _channel!.sink.add(jsonEncode({'type': 'offer', 'sdp': offer.sdp}));
  }

  Future<void> _flushPendingSignals() async {
    final queued = List<Map<String, dynamic>>.from(_pendingSignals);
    _pendingSignals.clear();
    for (final signal in queued) {
      await Future<void>.delayed(Duration.zero);
      _handleSignalingMessage(signal);
    }
  }

  Future<void> _flushPendingCandidates() async {
    if (_peerConnection == null || !_hasRemoteDescription) return;
    final queued = List<Map<String, dynamic>>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final data in queued) {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ),
      );
    }
  }

  Future<void> _setupPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _channel!.sink.add(
        jsonEncode({
          'type': 'candidate',
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }),
      );
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _statusMessage = 'Connected');
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(() {
          _statusMessage =
              'Video connection failed. End the call and join again.';
        });
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        setState(() {
          _statusMessage = 'Connection interrupted. Waiting to reconnect...';
        });
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (!mounted) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        setState(() {
          _statusMessage =
              'Network could not connect the video streams. Try both users on the same Wi-Fi or join again.';
        });
      }
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteRenderer.srcObject = stream;
      for (final track in stream.getAudioTracks()) {
        track.enabled = true;
      }
      if (mounted) {
        setState(() {
          _statusMessage = 'Connected';
        });
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isEmpty) return;
      _remoteRenderer.srcObject = event.streams.first;
      for (final track in event.streams.first.getAudioTracks()) {
        track.enabled = true;
      }
      if (mounted) {
        setState(() {
          _statusMessage = 'Connected';
        });
      }
    };

    // Add local stream tracks to peer connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    await _flushPendingSignals();
  }

  Future<void> _startCall() async {
    setState(() {
      _isStarting = true;
      _statusMessage = 'Requesting camera and microphone permission...';
    });

    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'googEchoCancellation': true,
        'googNoiseSuppression': true,
        'googAutoGainControl': true,
      },
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      },
    };

    try {
      MediaStream stream;
      try {
        stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      } catch (_) {
        stream = await navigator.mediaDevices.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': true,
        });
      }
      _localStream = stream;
      _localRenderer.srcObject = _localStream;

      await _setupPeerConnection();

      _channel?.sink.add(jsonEncode({'type': 'ready'}));
      if (widget.appointmentId != null) {
        final error = await VideoService.markPatientWaiting(
          widget.appointmentId!,
        );
        if (error != null && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      }
      if (_role == 'patient' && _remoteReady) await _sendOffer();

      setState(() {
        _inCall = true;
        _isStarting = false;
        _statusMessage = _role == 'patient'
            ? 'Doctor will be joining soon. Please stay on this screen.'
            : 'Waiting for patient video...';
      });
    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        _isStarting = false;
        _statusMessage =
            'Camera or microphone could not start. Make sure this page is HTTPS, then tap Start Secure Video and allow permissions.';
      });
    }
  }

  Future<void> _endCall() async {
    _channel?.sink.add(jsonEncode({'type': 'call-ended'}));
    await _cleanupCall('Call ended. Tap Start Secure Video to join again.');
  }

  Future<void> _handleRemoteEnded() async {
    await _cleanupCall('The other participant ended the call.');
  }

  Future<void> _cleanupCall(String message) async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    await _peerConnection?.close();
    _peerConnection = null;
    _remoteReady = false;
    _hasRemoteDescription = false;
    _pendingSignals.clear();
    _pendingCandidates.clear();
    if (widget.appointmentId != null) {
      await VideoService.clearWaitingCall(widget.appointmentId!);
    }

    setState(() {
      _inCall = false;
      _isMuted = false;
      _statusMessage = message;
    });
  }

  void _toggleMute() {
    final audioTracks = _localStream?.getAudioTracks() ?? [];
    final nextMuted = !_isMuted;
    for (final track in audioTracks) {
      track.enabled = !nextMuted;
    }
    setState(() => _isMuted = nextMuted);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Consultation (${widget.roomId})'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _remoteRenderer.srcObject != null
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isStarting)
                              const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            if (_isStarting) const SizedBox(height: 18),
                            Icon(
                              _role == 'doctor'
                                  ? Icons.video_call
                                  : Icons.hourglass_top,
                              color: Colors.white70,
                              size: 46,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            width: 120,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _localStream == null
                  ? const Center(
                      child: Icon(Icons.videocam_off, color: Colors.white70),
                    )
                  : RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_inCall)
                  FloatingActionButton.extended(
                    onPressed: !_isStarting ? _startCall : null,
                    backgroundColor: Colors.green,
                    icon: _isStarting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.video_call),
                    label: const Text('Start Secure Video'),
                  ),
                if (_inCall)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: FloatingActionButton(
                      onPressed: _toggleMute,
                      backgroundColor: _isMuted
                          ? Colors.grey.shade700
                          : Colors.blue,
                      child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                    ),
                  ),
                if (_inCall)
                  FloatingActionButton(
                    onPressed: _endCall,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
