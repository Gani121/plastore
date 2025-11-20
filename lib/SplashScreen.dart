import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
import 'main.dart'; // your next page

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    // _controller = VideoPlayerController.asset("assets/video/splash.mp4")
    //   ..initialize().then((_) {
    //     setState(() {}); // refresh when initialized
    //     _controller.play(); // auto play
    //   });

    // // Navigate when video ends
    // _controller.addListener(() {
    //   if (_controller.value.position >= _controller.value.duration &&
    //       !_controller.value.isPlaying) {
    //     _navigateNext();
    //   }
    // });
  }

  void _navigateNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DostiKitchenPage()),
    );
  }

  @override
  void dispose() {
    // _controller.dispose();
    super.dispose();
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     backgroundColor: Colors.white, // match your video bg
  //     body: Center(
  //       child: _controller.value.isInitialized
  //           ? AspectRatio(
  //               aspectRatio: _controller.value.aspectRatio,
  //               child: VideoPlayer(_controller),
  //             )
  //           : const CircularProgressIndicator(), // loader while initializing
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // same as your logo background
      body: Center(
        child:
        //  _controller.value.isInitialized
        //     ? const SizedBox(
        //         width: 60, // your desired width
        //         height: 60, // your desired height
        //         child: CircularProgressIndicator(
        //           strokeWidth: 6, // thickness of the circle
        //           valueColor: AlwaysStoppedAnimation<Color>(
        //             Colors.green,
        //           ), // color
        //         ),
        //       )
        //     : 
            const SizedBox(
                width: 60, // your desired width
                height: 60, // your desired height
                child: CircularProgressIndicator(
                  strokeWidth: 6, // thickness of the circle
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.green,
                  ), // color
                ),
              ),
      ),
    );
  }
}
