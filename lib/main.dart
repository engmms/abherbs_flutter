import 'dart:async';

import 'package:abherbs_flutter/generated/i18n.dart';
import 'package:abherbs_flutter/keys.dart';
import 'package:abherbs_flutter/prefs.dart';
import 'package:abherbs_flutter/splash.dart';
import 'package:abherbs_flutter/utils.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_crashlytics/flutter_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:screen/screen.dart';

class Ads {
  static BannerAd _bannerAd;
  static InterstitialAd _interstitialAd;
  static bool isShown = false;
  static bool _isGoingToBeShown = false;

  static void setBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      targetingInfo: _getMobileAdTargetingInfo(),
      listener: (MobileAdEvent event) {
        if (event == MobileAdEvent.loaded) {
          isShown = true;
          _isGoingToBeShown = false;
        } else if (event == MobileAdEvent.failedToLoad) {
          isShown = false;
          _isGoingToBeShown = false;
        }
        print("BannerAd event is $event");
      },
    );
  }

  static void showBannerAd([State state]) {
    if (state != null && !state.mounted) return;
    if (_bannerAd == null) setBannerAd();
    if (!isShown && !_isGoingToBeShown) {
      _isGoingToBeShown = true;
      _bannerAd
        ..load()
        ..show(anchorOffset: 60.0, anchorType: AnchorType.bottom);
    }
  }

  static void hideBannerAd() {
    if (_bannerAd != null && !_isGoingToBeShown) {
      _bannerAd.dispose().then((disposed) {
        isShown = !disposed;
      });
      _bannerAd = null;
    }
  }

  static void setInterstitialAd() {
    _interstitialAd = InterstitialAd(
      adUnitId: interstitialAdUnitId,
      targetingInfo: _getMobileAdTargetingInfo(),
      listener: (MobileAdEvent event) {
        print("InterstitialAd event is $event");
      },
    );
  }

  static void showInterstitialAd() {
    if (_interstitialAd == null) setInterstitialAd();
    _interstitialAd
      ..load()
      ..show(anchorOffset: 0.0, anchorType: AnchorType.bottom);
  }

  static void showRewardedVideoAd() {
    RewardedVideoAd.instance.listener =
        (RewardedVideoAdEvent event, {String rewardType, int rewardAmount}) {
      if (event == RewardedVideoAdEvent.loaded) {
        RewardedVideoAd.instance.show();
      }
    };
    RewardedVideoAd.instance.load(adUnitId: rewardAdUnitId, targetingInfo:_getMobileAdTargetingInfo());
  }

  static MobileAdTargetingInfo _getMobileAdTargetingInfo() {
    return MobileAdTargetingInfo(
      keywords: <String>['flower', 'identify flower', 'plant', 'tree', 'botany', 'identification key'],
      contentUrl: 'https://whatsthatflower.com/',
      childDirected: false,
      testDevices: <String>["E97A43B66C19A6831DFA72A48E922E5B"],
    );
  }
}

void main() async {
  bool isInDebugMode = false;

  FlutterError.onError = (FlutterErrorDetails details) {
    if (isInDebugMode) {
      // In development mode simply print to console.
      FlutterError.dumpErrorToConsole(details);
    } else {
      // In production mode report to the application zone to report to Crashlytics.
      Zone.current.handleUncaughtError(details.exception, details.stack);
    }
  };

  await FlutterCrashlytics().initialize();

  runZoned<Future<Null>>(() async {
    Screen.keepOn(true);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) {
      runApp(App());
    });
  }, onError: (error, stackTrace) async {
    await FlutterCrashlytics().reportCrash(error, stackTrace, forceCrash: false);
  });
}

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  Future<Locale> _localeF;

  onChangeLanguage(String language) {
    setState(() {
      _localeF = new Future<Locale>(() {
        return language.isEmpty ? null : Locale(language, '');
      });
    });
  }

  @override
  void initState() {
    super.initState();
    FirebaseAdMob.instance.initialize(appId: adAppId);

    Prefs.init();
    Prefs.getStringF(keyPreferredLanguage).then((String language) {
      onChangeLanguage(language);
    });

    Prefs.getIntF(keyRateCount, rateCountInitial).then((value) {
      if (value < 0) {
        Prefs.getStringF(keyRateState, rateStateInitial).then((value) {
          if (value == rateStateInitial) {
            Prefs.setString(keyRateState, rateStateShould);
          }
        });
      } else {
        Prefs.setInt(keyRateCount, value - 1);
      }
    });
  }

  @override
  void dispose() {
    Prefs.dispose();
    Ads.hideBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Locale>(
        future: _localeF,
        builder: (BuildContext context, AsyncSnapshot<Locale> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.done:
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: snapshot.data,
                localizationsDelegates: [
                  S.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                supportedLocales: S.delegate.supportedLocales,
                home: Splash(this.onChangeLanguage),
              );
            default:
              return const CircularProgressIndicator();
          }
        });
  }
}
