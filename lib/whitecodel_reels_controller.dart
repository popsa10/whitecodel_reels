import 'dart:async';
import 'dart:developer';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:whitecodel_reels/video_controller_service.dart';

// Controller class for managing the reels in the app
class WhiteCodelReelsController extends GetxController
    with GetTickerProviderStateMixin, WidgetsBindingObserver {
  // Page controller for managing pages of videos
  PageController pageController = PageController(viewportFraction: 0.8,);

  // List of BetterPlayer controllers
  RxList<BetterPlayerController> betterPlayerControllerList =
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

  final List<String> reelsVideoThumbnail;

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
  WhiteCodelReelsController({
    required this.reelsVideoList,
    required this.isCaching,
    this.startIndex = 0,
    required this.reelsVideoThumbnail,
  });

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
    for (var i = 0; i < betterPlayerControllerList.length; i++) {
      betterPlayerControllerList[i].pause();
      betterPlayerControllerList[i].dispose();
    }
    timer?.cancel();
    super.onClose();
  }

  // Initialize video service and load videos
  initService({int startIndex = 0}) async {
    await addVideosController();
    int myindex = startIndex;

    try {
      if (!betterPlayerControllerList[myindex].isVideoInitialized()!) {
        cacheVideo(myindex);
        await betterPlayerControllerList[myindex].setupDataSource(
          BetterPlayerDataSource(
            BetterPlayerDataSourceType.network,
            videoList[myindex],
            cacheConfiguration: BetterPlayerCacheConfiguration(
              useCache: isCaching,
            ),
            placeholder: Image.network(reelsVideoThumbnail[myindex],fit: BoxFit.cover,),
          ),
        );
        increasePage(myindex + 1);
      }
    } catch (e) {
      log('Error initializing video at index $myindex: $e');
    }

    animationController.repeat();
    betterPlayerControllerList[myindex].play();
    refreshView();
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
          videoFile, isCaching, reelsVideoThumbnail[i]);
      betterPlayerControllerList.add(controller);
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
          var controller = betterPlayerControllerList[i];
          if (!controller.isVideoInitialized()!) {
            cacheVideo(i);
            await controller.setupDataSource(
              BetterPlayerDataSource(
                BetterPlayerDataSourceType.network,
                videoList[i],
                cacheConfiguration: BetterPlayerCacheConfiguration(
                  useCache: isCaching,
                ),
                placeholder: Image.network(reelsVideoThumbnail[i],fit: BoxFit.cover,),
              ),
            );
            increasePage(i + 1);
            refreshView();
          }
        }
      }
      for (var i = index - 1; i > index - loadLimit; i--) {
        if (videoList.asMap().containsKey(i)) {
          var controller = betterPlayerControllerList[i];
          if (!controller.isVideoInitialized()!) {
            if (!caching.contains(videoList[index])) {
              cacheVideo(index);
            }

            await controller.setupDataSource(
              BetterPlayerDataSource(
                BetterPlayerDataSourceType.network,
                videoList[i],
                cacheConfiguration: BetterPlayerCacheConfiguration(
                  useCache: isCaching,
                ),
                placeholder: Image.network(reelsVideoThumbnail[i],fit: BoxFit.cover,),
              ),
            );
            increasePage(i + 1);
            refreshView();
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
    var oldBetterPlayerController = betterPlayerControllerList[index];
    if (oldBetterPlayerController.isVideoInitialized()!) {
      oldBetterPlayerController.play();
      refresh();
      return;
    }
    BetterPlayerController betterPlayerControllerTmp =
    await videoControllerService.getControllerForVideo(
        videoList[index], isCaching, reelsVideoThumbnail[index]);
    betterPlayerControllerList[index] = betterPlayerControllerTmp;
    oldBetterPlayerController.dispose();
    refreshView();
    if (!caching.contains(videoList[index])) {
      cacheVideo(index);
    }
    if(betterPlayerControllerTmp.isVideoInitialized()!){
      betterPlayerControllerTmp.play();
      refresh();
    }
  }

  // Dispose nearby old video controllers
  disposeNearByOldVideoControllers(int index) async {
    loading.value = false;
    for (var i = index - loadLimit; i > 0; i--) {
      if (betterPlayerControllerList.asMap().containsKey(i)) {
        var oldBetterPlayerController = betterPlayerControllerList[i];
        BetterPlayerController betterPlayerControllerTmp =
        await videoControllerService.getControllerForVideo(
            videoList[i], isCaching, reelsVideoThumbnail[index]);
        betterPlayerControllerList[i] = betterPlayerControllerTmp;
        alreadyListened.remove(i);
        oldBetterPlayerController.dispose();
        refreshView();
      }
    }

    for (var i = index + loadLimit; i < betterPlayerControllerList.length; i++) {
      if (betterPlayerControllerList.asMap().containsKey(i)) {
        var oldBetterPlayerController = betterPlayerControllerList[i];
        BetterPlayerController betterPlayerControllerTmp =
        await videoControllerService.getControllerForVideo(
            videoList[i], isCaching, reelsVideoThumbnail[index]);
        betterPlayerControllerList[i] = betterPlayerControllerTmp;
        alreadyListened.remove(i);
        oldBetterPlayerController.dispose();
        refreshView();
      }
    }
  }

  // Listen to video events
  listenEvents(i, {bool force = false}) {
    if (alreadyListened.contains(i) && !force) return;
    alreadyListened.add(i);
    var betterPlayerController = betterPlayerControllerList[i];

    betterPlayerController.addEventsListener((BetterPlayerEvent event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
        betterPlayerController.seekTo(Duration.zero);
        betterPlayerController.play();
      }
    });
  }

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

    try {
      await cacheManager.downloadFile(url);
    } catch (e) {
      caching.remove(url);
    }
  }

  increasePage(v) {
    if (pageCount.value == videoList.length) return;
    if (pageCount.value >= v) return;
    pageCount.value = v;
  }
}