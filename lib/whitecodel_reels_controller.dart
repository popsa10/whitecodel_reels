import 'dart:async';
import 'dart:developer';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'video_controller_service.dart';

// Controller class for managing the reels in the app
class WhiteCodelReelsController extends GetxController
    with GetTickerProviderStateMixin, WidgetsBindingObserver {
  // Page controller for managing pages of videos
  PageController pageController = PageController(viewportFraction: 0.99999);

  // List of video player controllers
  RxList<BetterPlayerController> videoPlayerControllerList =
      <BetterPlayerController>[].obs;

  // Service for managing cached video controllers
  CachedVideoControllerService videoControllerService =
  CachedVideoControllerService(DefaultCacheManager());

  // Observable for loading state
  final loading = true.obs;

  // Observable for visibility state
  final visible = false.obs;

  // Animation controller for animating
  late AnimationController animationController;

  // Animation object
  late Animation animation;

  // Current page index
  int page = 1;

  // Limit for loading videos
  int limit = 10;

  // List of video URLs
  final List<String> reelsVideoList;

  final List<String> reelsVideoThumbnailList;

  // isCaching
  bool isCaching;

  // Observable list of video URLs
  RxList<String> videoList = <String>[].obs;

  // Limit for loading nearby videos
  int loadLimit = 2;

  // Flag for initialization
  bool init = false;

  // Timer for periodic tasks
  Timer? timer;

  // Index of the last video
  int? lastIndex;

  // Already listened list
  List<int> alreadyListened = [];

  // Caching video at index
  List<String> caching = [];

  // pageCount
  RxInt pageCount = 0.obs;

  final int startIndex;

  // Constructor
  WhiteCodelReelsController(
      {required this.reelsVideoList,
        required this.isCaching,
        required this.reelsVideoThumbnailList,
        this.startIndex = 0});

  // // Lifecycle method for handling app lifecycle state changes
  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   super.didChangeAppLifecycleState(state);
  //   if (state == AppLifecycleState.paused) {
  //     // Pause all video players when the app is paused
  //     for (var i = 0; i < videoPlayerControllerList.length; i++) {
  //       videoPlayerControllerList[i].pause();
  //     }
  //   }
  // }

  // Lifecycle method called when the controller is initialized
  @override
  void onInit() {
    super.onInit();
    videoList.addAll(reelsVideoList);
    // Initialize animation controller
    animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5));
    animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeIn,
    );
    // Initialize service and start timer
    initService(startIndex: startIndex);
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (lastIndex != null) {
        initNearByVideos(lastIndex!);
      }
    });
  }

  // Lifecycle method called when the controller is closed
  @override
  void onClose() {
    animationController.dispose();
    // Pause and dispose all video players
    for (var i = 0; i < videoPlayerControllerList.length; i++) {
      videoPlayerControllerList[i].pause();
      videoPlayerControllerList[i].dispose();
    }
    timer?.cancel();
    super.onClose();
  }

  // Initialize video service and load videos
  initService({int startIndex = 0}) async {
    await addVideosController();
    int myindex = startIndex;

    try {
      if (!(videoPlayerControllerList[myindex].isVideoInitialized() ?? false)) {
        cacheVideo(myindex);
        videoPlayerControllerList[myindex] = BetterPlayerController(BetterPlayerConfiguration(
          placeholder: Image.network(reelsVideoThumbnailList[myindex],fit: BoxFit.cover,),
          looping: true,
          fit: BoxFit.cover,
          controlsConfiguration: BetterPlayerControlsConfiguration(
            showControlsOnInitialize: false,
            showControls: false
          )
        ),betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          reelsVideoList[myindex]
        ));
        increasePage(myindex + 1);
      }
    } catch (e) {
      log('Error initializing video at index $myindex: $e');
    }

    animationController.repeat();
    videoPlayerControllerList[myindex].play();
    refreshView();
    // listenEvents(myindex);
    await initNearByVideos(myindex);
    loading.value = false;

    Future.delayed(Duration.zero, () {
      pageController.jumpToPage(myindex);
    });
  }

  // Refresh loading state
  refreshView() {
    loading.value = true;
    loading.value = false;
  }

  // Add video controllers
  addVideosController() async {
    for (var i = 0; i < videoList.length; i++) {
      String videoFile = videoList[i];
      final controller = await videoControllerService.getControllerForVideo(
          videoFile, isCaching, reelsVideoThumbnailList[i]);
      videoPlayerControllerList.add(controller);
    }
  }

  // Initialize nearby videos
  initNearByVideos(int index) async {
    if (init) {
      lastIndex = index;
      return;
    }
    lastIndex = null;
    init = true;
    if (loading.value) return;
    disposeNearByOldVideoControllers(index);
    await tryInit(index);
    try {
      var currentPage = index;
      var maxPage = currentPage + loadLimit;
      List<String> videoFiles = videoList;

      for (var i = currentPage; i < maxPage; i++) {
        if (videoFiles.asMap().containsKey(i)) {
          var controller = videoPlayerControllerList[i];
          if (!(controller.isVideoInitialized() ?? false)) {
            cacheVideo(i);
             controller = BetterPlayerController(BetterPlayerConfiguration(
                placeholder: Image.network(reelsVideoThumbnailList[i],fit: BoxFit.cover,),
                looping: true,
                fit: BoxFit.cover,
                controlsConfiguration: BetterPlayerControlsConfiguration(
                    showControlsOnInitialize: false,
                    showControls: false
                )
            ),betterPlayerDataSource: BetterPlayerDataSource(
                BetterPlayerDataSourceType.network,
                videoFiles[i]
            ));
            increasePage(i + 1);
            refreshView();
            // listenEvents(i);
          }
        }
      }
      for (var i = index - 1; i > index - loadLimit; i--) {
        if (videoList.asMap().containsKey(i)) {
          var controller = videoPlayerControllerList[i];
          if (!(controller.isVideoInitialized() ?? false)) {
            if (!caching.contains(videoList[index])) {
              cacheVideo(index);
            }

             controller = BetterPlayerController(BetterPlayerConfiguration(
                placeholder: Image.network(reelsVideoThumbnailList[index],fit: BoxFit.cover,),
                looping: true,
                fit: BoxFit.cover,
                controlsConfiguration: BetterPlayerControlsConfiguration(
                    showControlsOnInitialize: false,
                    showControls: false
                )
            ),betterPlayerDataSource: BetterPlayerDataSource(
                BetterPlayerDataSourceType.network,
                 videoList[index]
            ));
            increasePage(i + 1);
            refreshView();
            // listenEvents(i);
          }
        }
      }

      refreshView();
      loading.value = false;
    } catch (e) {
      loading.value = false;
    } finally {
      loading.value = false;
    }
    init = false;
  }

  // Try initializing video at index
  tryInit(int index) async {
    var oldVideoPlayerController = videoPlayerControllerList[index];
    if (oldVideoPlayerController.isVideoInitialized() ?? false) {
      oldVideoPlayerController.play();
      refresh();
      return;
    }
    BetterPlayerController videoPlayerControllerTmp =
    await videoControllerService.getControllerForVideo(
        videoList[index], isCaching, reelsVideoThumbnailList[index]);
    videoPlayerControllerList[index] = videoPlayerControllerTmp;
     oldVideoPlayerController.dispose();
    refreshView();
    if (!caching.contains(videoList[index])) {
      cacheVideo(index);
    }
     videoPlayerControllerTmp = BetterPlayerController(BetterPlayerConfiguration(
        placeholder: Image.network(reelsVideoThumbnailList[index],fit: BoxFit.cover,),
        looping: true,
        fit: BoxFit.cover,
        controlsConfiguration: BetterPlayerControlsConfiguration(
            showControlsOnInitialize: false,
            showControls: false
        )
    ),betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        videoList[index]
    ));
    videoPlayerControllerTmp.play();
    refresh();
  }

  // Dispose nearby old video controllers
  disposeNearByOldVideoControllers(int index) async {
    loading.value = false;
    for (var i = index - loadLimit; i > 0; i--) {
      if (videoPlayerControllerList.asMap().containsKey(i)) {
        var oldVideoPlayerController = videoPlayerControllerList[i];
        BetterPlayerController videoPlayerControllerTmp =
        await videoControllerService.getControllerForVideo(
            videoList[i], isCaching, reelsVideoThumbnailList[i]);
        videoPlayerControllerList[i] = videoPlayerControllerTmp;
        alreadyListened.remove(i);
        oldVideoPlayerController.dispose();
        refreshView();
      }
    }

    for (var i = index + loadLimit; i < videoPlayerControllerList.length; i++) {
      if (videoPlayerControllerList.asMap().containsKey(i)) {
        var oldVideoPlayerController = videoPlayerControllerList[i];
        BetterPlayerController videoPlayerControllerTmp =
        await videoControllerService.getControllerForVideo(
            videoList[i], isCaching, reelsVideoThumbnailList[i]);
        videoPlayerControllerList[i] = videoPlayerControllerTmp;
        alreadyListened.remove(i);
        oldVideoPlayerController.dispose();
        refreshView();
      }
    }
  }

  // Listen to video events
  listenEvents(i, {bool force = false}) {
    if (alreadyListened.contains(i) && !force) return;
    alreadyListened.add(i);
    var videoPlayerController = videoPlayerControllerList[i];

    videoPlayerController.videoPlayerController?.addListener(() {
      if (videoPlayerController.videoPlayerController?.value.position ==
          videoPlayerController.videoPlayerController?.value.duration &&
          videoPlayerController.videoPlayerController?.value.duration != Duration.zero) {
        videoPlayerController.seekTo(Duration.zero);
        videoPlayerController.play();
      }
    });
  }

  // Listen to page events
  // pageEventsListen(path) {
  //   pageController.addListener(() {
  //     visible.value = false;
  //     Future.delayed(const Duration(milliseconds: 500), () {
  //       loading.value = false;
  //     });
  //     refreshView();
  //   });
  // }

  cacheVideo(int index) async {
    if (!isCaching) return;
    String url = videoList[index];
    if (caching.contains(url)) return;
    caching.add(url);
    final cacheManager = DefaultCacheManager();
    FileInfo? fileInfo = await cacheManager.getFileFromCache(url);
    if (fileInfo != null) {
      log('Video already cached: $index');
      return;
    }

    // log('Downloading video: $index');
    try {
      await cacheManager.downloadFile(url);
      // log('Downloaded video: $index');
    } catch (e) {
      // log('Error downloading video: $e');
      caching.remove(url);
    }
  }

  increasePage(v) {
    if (pageCount.value == videoList.length) return;
    if (pageCount.value >= v) return;
    pageCount.value = v;
  }
}