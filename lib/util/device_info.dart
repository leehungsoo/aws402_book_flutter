import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfo {
  const DeviceInfo._();

  static Future<void> checkPlatform() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if(kIsWeb){
      WebBrowserInfo webBrowserInfo = await deviceInfo.webBrowserInfo;
    }else{
      if(Platform.isAndroid){
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int version = androidInfo.version.sdkInt;
        String board = androidInfo.board;
        String bootloader = androidInfo.bootloader;
        String brand = androidInfo.brand;
        String device = androidInfo.device;
        String display = androidInfo.display;
        String fingerprint = androidInfo.fingerprint;
        String hardware = androidInfo.hardware;
        String host = androidInfo.host;
        String model = androidInfo.model;
        // print('version=$version\nboard=$board\nbootloader=$bootloader\nbrand=$brand');
        // print('device=$device\ndisplay=$display\nfingerprint=$fingerprint\nhardware=$hardware');
        // print('host=$host\nmodel=$model');
      }else if(Platform.isIOS){
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      }
    }
  }
}