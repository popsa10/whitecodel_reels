library whitecodel_reels;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'whitecodel_reels_controller.dart';

class WhiteCodelReels extends GetView<WhiteCodelReelsController> {
  final BuildContext context;
  final List<String>? videoList;
  final Widget? loader;
  final bool isCaching;
  final int startIndex;
  final List<String>? videoThumbnailList;
  final Widget Function(
    BuildContext context,
    int index,
    Widget child,
      BetterPlayerController videoPlayerController,
    PageController pageController,
  )? builder;

  const WhiteCodelReels({
    super.key,
    required this.context,
    required this.videoThumbnailList,
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
      reelsVideoThumbnail: videoThumbnailList ?? []
        ));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(
        () => PageView.builder(
          controller: controller.pageController,
          itemCount: controller.pageCount.value,
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
          controller.betterPlayerControllerList[index].seekTo(Duration.zero);
          controller.betterPlayerControllerList[index].pause();
          // controller.visible.value = true;
          controller.refreshView();
          controller.animationController.stop();
        } else {
          controller.listenEvents(index);
          controller.betterPlayerControllerList[index].play();
          // controller.visible.value = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            // controller.visible.value = false;
          });
          controller.refreshView();
          controller.animationController.repeat();
          controller.initNearByVideos(index);
          if (!controller.caching.contains(controller.videoList[index])) {
            controller.cacheVideo(index);
          }
          controller.visible.value = false;
        }
      },
      child: GestureDetector(
        onTap: () {
          if (controller.betterPlayerControllerList[index].isPlaying()!) {
            controller.betterPlayerControllerList[index].pause();
            controller.visible.value = true;
            controller.refreshView();
            controller.animationController.stop();
          } else {
            controller.betterPlayerControllerList[index].play();
            controller.visible.value = true;
            Future.delayed(const Duration(milliseconds: 500), () {
              controller.visible.value = false;
            });

            controller.refreshView();
            controller.animationController.repeat();
          }
        },
        child: Obx(() {
          if (controller.loading.value ||
              !(controller
                  .betterPlayerControllerList[index].isVideoInitialized() ?? false)) {
            return loader ?? const Center(child: CircularProgressIndicator());
          }

          return builder == null
              ? VideoFullScreenPage(
                  videoPlayerController:
                      controller.betterPlayerControllerList[index])
              : builder!(
                  context,
                  index,
                  VideoFullScreenPage(
                    videoPlayerController:
                        controller.betterPlayerControllerList[index],
                  ),
                  controller.betterPlayerControllerList[index],
                  controller.pageController);
        }),
      ),
    );
  }
}

class VideoFullScreenPage extends StatelessWidget {
  final BetterPlayerController videoPlayerController;

  const VideoFullScreenPage({super.key, required this.videoPlayerController});

  @override
  Widget build(BuildContext context) {
    WhiteCodelReelsController controller =
        Get.find<WhiteCodelReelsController>();
    return Stack(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: MediaQuery.of(context).size.height *
                  videoPlayerController.videoPlayerController!.value.aspectRatio,
              height: MediaQuery.of(context).size.height,
              child: BetterPlayer(controller: videoPlayerController),
            ),
          ),
        ),
        Positioned(
          child: Center(
            child: Obx(
              () => Opacity(
                opacity: .5,
                child: AnimatedOpacity(
                  opacity: controller.visible.value ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    alignment: Alignment.center,
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(
                          color: Colors.white,
                          width: 1,
                        ),
                      ),
                    ),
                    child: videoPlayerController.isPlaying()!
                        ? const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          )
                        : const Icon(
                            Icons.pause,
                            color: Colors.white,
                            size: 40,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
