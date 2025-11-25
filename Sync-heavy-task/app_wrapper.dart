import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/core/application/auth_bloc.dart';
import '../../features/download/application/bloc/download_bloc.dart';
import '../../features/home/application/home_bloc.dart';
import '../../features/notifications/application/notification_bloc.dart';
import '../../features/notifications/application/notification_list/notification_list_bloc.dart';
import '../../injection.dart';
import '../../routes/router.gr.dart';
import '../../utils/main.dart';
import '../application/app/app_bloc.dart';
import '../application/sync/sync_bloc.dart';
import '../infrastructure/notification_api.dart';
import 'constants/app_colors.dart';
import 'no_connection_banner.dart';

@RoutePage()
class AppWrapperPage extends StatefulWidget implements AutoRouteWrapper {
  const AppWrapperPage({super.key});

  @override
  State<AppWrapperPage> createState() => _AppWrapperPageState();

  @override
  Widget wrappedRoute(BuildContext context) {
    final String defaultLocale = Platform.localeName.split('_')[0];
    return MultiBlocProvider(
      providers: <BlocProvider<Bloc<dynamic, dynamic>>>[
        BlocProvider<AppBloc>(
          lazy: false,
          create: (BuildContext context) => getIt<AppBloc>()
            ..add(AppEvent.initLanguage(locale: defaultLocale)),
        ),
        BlocProvider<AuthBloc>(
          lazy: false,
          create: (BuildContext context) {
            final AuthBloc authBloc = getIt<AuthBloc>();
            authBloc.add(const AuthEvent.authCheckToken());
            authBloc.add(const AuthEvent.authCheckRequested());
            return authBloc;
          },
        ),
        BlocProvider<SyncBloc>(create: (_) => getIt<SyncBloc>()),
        BlocProvider<HomeBloc>(create: (_) => getIt<HomeBloc>()),
        BlocProvider<NotificationBloc>(
          create: (BuildContext context) => getIt<NotificationBloc>(),
        ),
        BlocProvider<NotificationListBloc>(
          lazy: false,
          create: (BuildContext context) => getIt<NotificationListBloc>(),
        ),
        BlocProvider<DownloadBloc>(create: (_) => getIt<DownloadBloc>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<AppBloc, AppState>(listener: (context, state) {
            context.setLocale(Locale(state.locale));
          }),
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (previous, current) =>
                current.accessToken != null &&
                previous.accessToken != current.accessToken,
            listener: (context, state) async {
              final hasInternet = await Utils.hasInternetConnection();
              if (hasInternet) {
                // Start sync in background without blocking navigation
                Future.microtask(() {
                  if (context.mounted) {
                    context
                        .read<SyncBloc>()
                        .add(const SyncEvent.syncStarted(isAppStart: true, runInBackground: true));
                  }
                });

                Future.microtask(() {
                  if (context.mounted) {
                    context
                      .read<NotificationListBloc>()
                      .add(const NotificationListEvent.countUnread());
                  }
                });
              } else {
                // No internet - skip sync and allow navigation
                Future.microtask(() {
                  if (context.mounted) {
                    context.read<SyncBloc>().add(const SyncEvent.skipFirstSync());
                  }
                });
              }

              final notificationToken =
                  await getIt<NotificationApi>().getFCMToken();
              if (notificationToken != null) {
                getIt<NotificationBloc>().add(
                    NotificationEvent.subscribeNotification(
                        notificationToken: notificationToken));
              }
            },
          ),
        ],
        child: this,
      ),
    );
  }
}

class _AppWrapperPageState extends State<AppWrapperPage>
    with WidgetsBindingObserver, AutoRouteAwareStateMixin<AppWrapperPage> {
  bool _hasConnection = true;
  late final StreamSubscription<List<ConnectivityResult>>
      _connectivitySubscription;
  bool _showBackOnline = false;
  Timer? _backOnlineTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadBloc>().add(const DownloadEvent.getLastSyncAt());
    });
    WidgetsBinding.instance.addObserver(this);
    getIt<NotificationApi>().initLocalNotification(context);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) {
        return;
      }
      context
          .read<NotificationListBloc>()
          .add(const NotificationListEvent.countUnread());
    });
    _checkConnection();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasConnection = await Utils.hasInternetConnection();
      if (mounted) {
        if (!hasConnection) {
          _backOnlineTimer?.cancel();
          setState(() {
            _hasConnection = false;
            _showBackOnline = false;
          });
        } else {
          if (!_hasConnection) {
            setState(() {
              _showBackOnline = true;
              _hasConnection = true;
            });
            _backOnlineTimer?.cancel();
            _backOnlineTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  _showBackOnline = false;
                });
              }
            });
          } else {
            setState(() {
              _hasConnection = true;
            });
          }
        }
      }
    });
  }

  Future<void> _checkConnection() async {
    final hasConnection = await Utils.hasInternetConnection();
    if (mounted) {
      setState(() {
        _hasConnection = hasConnection;
      });
    }
  }

  @override
  void dispose() {
    context.read<AutoRouteObserver>().unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthBloc>().add(const AuthEvent.authCheckRequested());
      context
          .read<NotificationListBloc>()
          .add(const NotificationListEvent.countUnread());
      getIt<NotificationApi>().clearBadge();
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = context.watch<SyncBloc>().state;
    final authState = context.watch<AuthBloc>().state;

    final bool isAuthLoading = authState.isLoading ?? true;
    // Removed shouldShowSyncSplash - sync now runs in background
    final bool shouldShowSpinner =
        syncState.isShowSpinner && authState.accessToken != null;

    final List<PageRouteInfo> routes;
    if (isAuthLoading || shouldShowSpinner) {
      routes = [const SplashRoute()];
    } else if (authState.accessToken == null) {
      routes = [const SignInRoute()];
    } else {
      routes = [const HomeRoute()];
    }

    return Scaffold(
      body: PopScope(
        canPop: false,
        child: AutoRouter.declarative(
          routes: (_) => routes,
        ),
      ),
      bottomNavigationBar: !_hasConnection
          ? NoConnectionBanner(
              message: context.tr('No Connection'),
              backgroundColor: AppColors.polarisBlackColor,
              icon: Icons.wifi_off,
            )
          : _showBackOnline
              ? const _OnlineBannerSlide()
              : null,
    );
  }
}

class _OnlineBannerSlide extends StatefulWidget {
  const _OnlineBannerSlide();

  @override
  State<_OnlineBannerSlide> createState() => _OnlineBannerSlideState();
}

class _OnlineBannerSlideState extends State<_OnlineBannerSlide> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _visible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeIn,
      child: NoConnectionBanner(
        message: context.tr('You’re back online!'),
        backgroundColor: AppColors.textGreen6,
        icon: Icons.wifi,
      ),
    );
  }
}
