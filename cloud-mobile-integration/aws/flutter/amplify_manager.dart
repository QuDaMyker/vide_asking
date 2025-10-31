import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:flutter/foundation.dart';

/// AWS Amplify Manager for Flutter
/// Handles initialization and configuration of AWS Amplify
class AmplifyManager {
  static final AmplifyManager _instance = AmplifyManager._internal();
  factory AmplifyManager() => _instance;
  AmplifyManager._internal();

  bool _isConfigured = false;

  /// Initialize AWS Amplify with all plugins
  Future<void> initialize() async {
    if (_isConfigured) {
      debugPrint('Amplify already configured');
      return;
    }

    try {
      // Add plugins
      await Amplify.addPlugins([
        AmplifyAuthCognito(),
        AmplifyStorageS3(),
        AmplifyAPI(),
        AmplifyDataStore(modelProvider: ModelProvider.instance),
      ]);

      // Configure Amplify
      await Amplify.configure(amplifyconfig);

      _isConfigured = true;
      debugPrint('Amplify configured successfully');
    } on AmplifyAlreadyConfiguredException {
      debugPrint('Amplify was already configured. Was the app restarted?');
      _isConfigured = true;
    } catch (e) {
      debugPrint('Error configuring Amplify: $e');
      rethrow;
    }
  }

  /// Check if Amplify is configured
  bool get isConfigured => _isConfigured;

  /// Get configuration status
  AmplifyStatus getStatus() {
    return AmplifyStatus(
      isConfigured: _isConfigured,
      hasAuth: _hasPlugin<AmplifyAuthCognito>(),
      hasStorage: _hasPlugin<AmplifyStorageS3>(),
      hasAPI: _hasPlugin<AmplifyAPI>(),
      hasDataStore: _hasPlugin<AmplifyDataStore>(),
    );
  }

  bool _hasPlugin<T>() {
    try {
      Amplify.getPlugin(T);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Amplify status
class AmplifyStatus {
  final bool isConfigured;
  final bool hasAuth;
  final bool hasStorage;
  final bool hasAPI;
  final bool hasDataStore;

  AmplifyStatus({
    required this.isConfigured,
    required this.hasAuth,
    required this.hasStorage,
    required this.hasAPI,
    required this.hasDataStore,
  });

  @override
  String toString() {
    return 'AmplifyStatus(configured: $isConfigured, auth: $hasAuth, '
        'storage: $hasStorage, api: $hasAPI, dataStore: $hasDataStore)';
  }
}

/// Amplify configuration (from amplifyconfiguration.dart)
const amplifyconfig = '''
{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/0.1.0",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CredentialsProvider": {
          "CognitoIdentity": {
            "Default": {
              "PoolId": "YOUR_IDENTITY_POOL_ID",
              "Region": "YOUR_REGION"
            }
          }
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "YOUR_USER_POOL_ID",
            "AppClientId": "YOUR_APP_CLIENT_ID",
            "Region": "YOUR_REGION"
          }
        }
      }
    }
  },
  "storage": {
    "plugins": {
      "awsS3StoragePlugin": {
        "bucket": "YOUR_BUCKET_NAME",
        "region": "YOUR_REGION",
        "defaultAccessLevel": "guest"
      }
    }
  }
}
''';
