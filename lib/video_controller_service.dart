// Importing necessary packages
import 'dart:async'; // For asynchronous operations
import 'dart:developer'; // For logging

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // For caching files

// Abstract class defining a service for obtaining video controllers
abstract class VideoControllerService {
  // Method to get a VideoPlayerController for a given video URL
  Future<BetterPlayerController> getControllerForVideo(
      String url, bool isCaching,String thumbnail);
}

// Implementation of VideoControllerService that uses caching
class CachedVideoControllerService extends VideoControllerService {
  final BaseCacheManager _cacheManager; // Cache manager instance

  // Constructor requiring a cache manager instance
  CachedVideoControllerService(this._cacheManager);

  @override
  Future<BetterPlayerController> getControllerForVideo(
      String url, bool isCaching,String thumbnail) async {
    if (isCaching) {
      FileInfo?
          fileInfo; // Variable to store file info if video is found in cache

      try {
        // Attempt to retrieve video file from cache
        fileInfo = await _cacheManager.getFileFromCache(url);
      } catch (e) {
        // Log error if encountered while getting video from cache
        log('Error getting video from cache: $e');
      }

      // Check if video file was found in cache
      if (fileInfo != null) {
        // Log that video was found in cache
        // log('Video found in cache');
        // Return VideoPlayerController for the cached file
        return BetterPlayerController(
            betterPlayerDataSource: BetterPlayerDataSource(BetterPlayerDataSourceType.file, fileInfo.file.path),
            BetterPlayerConfiguration(
                controlsConfiguration: BetterPlayerControlsConfiguration(
                    showControlsOnInitialize: false,
                    showControls: false
                ),
                fit: BoxFit.cover,
                looping: true,
                autoPlay: true,
                placeholder: Image.network(thumbnail)
            ));
      }

      try {
        // If video is not found in cache, attempt to download it
        _cacheManager.downloadFile(url);
      } catch (e) {
        // Log error if encountered while downloading video
        log('Error downloading video: $e');
      }
    }

    // Return VideoPlayerController for the video from the network
    return BetterPlayerController(
        betterPlayerDataSource: BetterPlayerDataSource(BetterPlayerDataSourceType.network, url),
        BetterPlayerConfiguration(
            controlsConfiguration: BetterPlayerControlsConfiguration(
                showControlsOnInitialize: false,
                showControls: false
            ),
            fit: BoxFit.cover,
            looping: true,
            autoPlay: true,
            placeholder: Image.network(thumbnail)
        ));
  }
}
