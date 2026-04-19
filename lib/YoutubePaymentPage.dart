// playlist_player_page.dart
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../database_Module/video_model.dart';
import './api_service.dart';
import 'package:test1/utilities.dart';

class PlaylistPlayerPage extends StatefulWidget {
  const PlaylistPlayerPage({super.key});

  @override
  State<PlaylistPlayerPage> createState() => _PlaylistPlayerPageState();
}

class _PlaylistPlayerPageState extends State<PlaylistPlayerPage> {
  late YoutubePlayerController _controller;
  List<TrainingVideo> _videos = [];
  bool _isLoading = true;
  String? _error;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      final videos = await ApiService().getVideos();
      // print("videos $videos");
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
      
      if (videos.isNotEmpty) {
        _initializePlayer(videos.first.videoCode);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _initializePlayer(String videoId) {
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: true,
      ),
    )..addListener(() {
        if (mounted && _controller.value.isReady && !_isPlayerReady) {
          setState(() {
            _isPlayerReady = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training Videos')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training Videos')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                    _fetchVideos();
                  });
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training Videos')),
        body: const Center(child: Text('No videos available')),
      );
    }

    return YoutubePlayerBuilder(
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Training Videos'),
            backgroundColor: Colors.green[800],
          ),
          body: Column(
            children: [
              // Player
              AspectRatio(
                aspectRatio: 16 / 9,
                child: player,
              ),
              
              // Now playing info
              if (_isPlayerReady)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Now Playing: ${_getCurrentVideo()?.title ?? ""}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Playlist
              Expanded(
                child: ListView.builder(
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    final isPlaying = _isPlayerReady && 
                        _controller.metadata?.videoId == video.videoCode;
                    
                    return ListTile(
                      leading: Icon(
                        isPlaying ? Icons.play_circle : Icons.play_circle_outline,
                        color: isPlaying ? Colors.green : null,
                      ),
                      title: Text(video.title),
                      subtitle: video.description != null 
                          ? Text(
                              video.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: isPlaying 
                          ? const Icon(Icons.volume_up, size: 16)
                          : null,
                      onTap: () {
                        if (_isPlayerReady) {
                          _controller.load(video.videoCode);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.amber,
        onReady: () {
          debugPrint('Player is ready.');
          setState(() {
            _isPlayerReady = true;
          });
        },
        onEnded: (data) {
          // Auto-play next video
          final currentIndex = _videos.indexWhere(
            (v) => v.videoCode == data.videoId
          );
          if (currentIndex < _videos.length - 1) {
            _controller.load(_videos[currentIndex + 1].videoCode);
          }
        },
      ),
    );
  }
  
  TrainingVideo? _getCurrentVideo() {
    if (!_isPlayerReady) return null;
    final currentId = _controller.metadata?.videoId;
    return _videos.firstWhere(
      (v) => v.videoCode == currentId,
      orElse: () => _videos.first,
    );
  }
}