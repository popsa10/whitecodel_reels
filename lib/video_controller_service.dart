// Importing necessary packages
import 'dart:async'; // For asynchronous operations
import 'dart:developer'; // For logging
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Abstract class defining a service for obtaining better player controllers
abstract class VideoControllerService {
  // Method to get a BetterPlayerController for a given video URL
  Future<BetterPlayerController> getControllerForVideo(
      String url, bool isCaching, String thumbnail);
}

// Implementation of VideoControllerService that uses caching
class CachedVideoControllerService extends VideoControllerService {
  final BaseCacheManager _cacheManager; // Cache manager instance

  // Constructor requiring a cache manager instance
  CachedVideoControllerService(this._cacheManager);

  @override
  Future<BetterPlayerController> getControllerForVideo(
      String url, bool isCaching, String thumbnail) async {
    String videoUrl = url;

    if (isCaching) {
      FileInfo? fileInfo; // Variable to store file info if video is found in cache

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
        // Use the cached file path
        videoUrl = fileInfo.file.path;
      } else {
        try {
          // If video is not found in cache, attempt to download it
          await _cacheManager.downloadFile(url);
        } catch (e) {
          // Log error if encountered while downloading video
          log('Error downloading video: $e');
        }
      }
    }

    // Create BetterPlayerDataSource
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      videoUrl,
      cacheConfiguration: BetterPlayerCacheConfiguration(
        useCache: isCaching,
        preCacheSize: 10 * 1024 * 1024, // 10MB pre-cache size
        maxCacheSize: 100 * 1024 * 1024, // 100MB max cache size
        maxCacheFileSize: 10 * 1024 * 1024, // 10MB max single file cache size
      ),
      placeholder: thumbnail.isNotEmpty ? Image.network(thumbnail) : null,
    );

    // Create BetterPlayerConfiguration
    BetterPlayerConfiguration configuration = const BetterPlayerConfiguration(
      autoPlay: true,
      looping: true,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        showControls: false,
        showControlsOnInitialize: false,
      ),
      fit: BoxFit.cover,

    );

    // Return the BetterPlayerController with the configuration and data source
    return BetterPlayerController(configuration, betterPlayerDataSource: dataSource);
  }
}