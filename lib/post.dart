import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

class PostFetcher {
  String? _after;
  Future<List<Post>> getNext() async {
    final res = await http.get(Uri.parse(
        "https://www.reddit.com/r/funnycats.json${_after != null ? "?after=$_after" : ""}"));
    final parsed = jsonDecode(res.body);
    _after = parsed["data"]["after"];
    List data = parsed["data"]["children"];
    List<Post> posts = [];
    for (final element in data) {
      if (element["data"]["is_video"]) {
        posts.add(Post(
            videoUrl: element["data"]["media"]["reddit_video"]["hls_url"]));
      }
      List? crosspostParentList = element["data"]["crosspost_parent_list"];
      if (crosspostParentList != null) {
        for (var element in crosspostParentList) {
          if (element["is_video"]) {
            posts.add(
                Post(videoUrl: element["media"]["reddit_video"]["hls_url"]));
          }
        }
      }
    }
    return posts;
  }
}

class Post {
  final String videoUrl;

  Post({required this.videoUrl});
}

class PostList extends StatefulWidget {
  const PostList({super.key});

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  final PostFetcher postFetcher = PostFetcher();
  final List<Post> _posts = [];
  final PageController _pageController = PageController();

  Future _fetchData() async {
    List<Post> posts = await postFetcher.getNext();
    setState(() {
      _posts.addAll(posts);
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        if (index == _posts.length - 1) {
          _fetchData();
        }
        return PostItem(
          videoUrl: _posts[index].videoUrl,
        );
      },
    );
  }
}

class PostItem extends StatefulWidget {
  final String videoUrl;

  const PostItem({super.key, required this.videoUrl});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl);
    _initializeVideoPlayerFuture = _controller.initialize();
    _controller.play();
  }

  Widget buildVideo() {
    if (_controller.value.isInitialized) {
      return AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: GestureDetector(
              onTap: () {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              },
              child: VideoPlayer(_controller)));
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return const Center(
                  child: Text("Nie udało się załadować filmiku!",
                      style: TextStyle(fontSize: 20)));
            }
            return Center(child: Card(child: buildVideo()));
          }
          return const Center(
            child: CircularProgressIndicator(),
          );
        });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
