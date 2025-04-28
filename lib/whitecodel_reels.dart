library whitecodel_reels;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'whitecodel_reels_controller.dart';

class WhiteCodelReels extends GetView<WhiteCodelReelsController> {
  final BuildContext context;
  final List<String>? videoList;
  final Widget? loader;
  final bool isCaching;
  final int startIndex;
  final Widget Function(
      BuildContext context,
      int index,
      Widget child,
      VideoPlayerController videoPlayerController,
      PageController pageController,
      )? builder;

  const WhiteCodelReels({
    super.key,
    required this.context,
    this.videoList,
    this.loader,
    this.isCaching = false,
    this.builder,
    this.startIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    Get.delete<WhiteCodelReelsController>();
    Get.lazyPut<WhiteCodelReelsController>(() => WhiteCodelReelsController(
      reelsVideoList: videoList ?? [],
      isCaching: isCaching,
      startIndex: startIndex,
    ));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(
            () => PageView.builder(
          controller: controller.pageController,
          itemCount: controller.pageCount.value,
          padEnds: true,
          scrollDirection: Axis.vertical,
          itemBuilder: (context, index) {
            return buildTile(index);
          },
        ),
      ),
    );
  }

  buildTile(index) {
    return VisibilityDetector(
      key: Key(index.toString()),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction < 0.5) {
          controller.videoPlayerControllerList[index].seekTo(Duration.zero);
          controller.videoPlayerControllerList[index].pause();
          controller.refreshView();

        } else {
          controller.listenEvents(index);
          controller.videoPlayerControllerList[index].play();

          controller.refreshView();
          controller.initNearByVideos(index);
          if (!controller.caching.contains(controller.videoList[index])) {
            controller.cacheVideo(index);
          }

        }
      },
      child: Obx(() {
        if (!controller
                .videoPlayerControllerList[index].value.isInitialized) {
          return loader ?? const Center(child: CircularProgressIndicator());
        }

        return builder == null
            ? VideoFullScreenPage(
            videoPlayerController:
            controller.videoPlayerControllerList[index])
            : builder!(
            context,
            index,
            VideoFullScreenPage(
              videoPlayerController:
              controller.videoPlayerControllerList[index],
            ),
            controller.videoPlayerControllerList[index],
            controller.pageController);
      }),
    );
  }
}

class VideoFullScreenPage extends StatelessWidget {
  final VideoPlayerController videoPlayerController;

  const VideoFullScreenPage({super.key, required this.videoPlayerController});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: FittedBox(
        fit: BoxFit.cover,
        child: VideoPlayer(videoPlayerController),
      ),
    );
  }
}