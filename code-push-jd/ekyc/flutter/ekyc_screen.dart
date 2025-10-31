import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ekyc_viewmodel.dart';
import 'nfc_reader.dart';

/// Main eKYC screen with Material Design 3
/// Implements accessibility and responsive layout
class EKYCScreen extends StatefulWidget {
  const EKYCScreen({Key? key}) : super(key: key);

  @override
  State<EKYCScreen> createState() => _EKYCScreenState();
}

class _EKYCScreenState extends State<EKYCScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EKYCViewModel(),
      child: const _EKYCScreenContent(),
    );
  }
}

class _EKYCScreenContent extends StatelessWidget {
  const _EKYCScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EKYCViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('eKYC Verification'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status card
              _StatusCard(state: viewModel.state),
              const SizedBox(height: 24),

              // Progress indicator for NFC reading
              if (viewModel.state.type == EKYCStateType.readingNFC)
                const _NFCReadingProgress(),

              const SizedBox(height: 24),

              // Main content based on state
              _buildMainContent(context, viewModel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, EKYCViewModel viewModel) {
    switch (viewModel.state.type) {
      case EKYCStateType.initial:
        return _InitialContent(viewModel: viewModel);
      case EKYCStateType.mrzScanned:
        return _MRZScannedContent(viewModel: viewModel);
      case EKYCStateType.success:
        return _SuccessContent(viewModel: viewModel);
      case EKYCStateType.submitted:
        return const _SubmittedContent();
      case EKYCStateType.error:
        return _ErrorContent(
          message: viewModel.state.errorMessage ?? 'Unknown error',
          onRetry: () => viewModel.reset(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Status card showing current state
class _StatusCard extends StatelessWidget {
  final EKYCState state;

  const _StatusCard({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    IconData icon;
    String title;
    String message;

    switch (state.type) {
      case EKYCStateType.success:
        backgroundColor = colorScheme.primaryContainer;
        icon = Icons.check_circle;
        title = 'Verified';
        message = 'ID verification completed';
        break;
      case EKYCStateType.error:
        backgroundColor = colorScheme.errorContainer;
        icon = Icons.error;
        title = 'Error';
        message = state.errorMessage ?? 'An error occurred';
        break;
      case EKYCStateType.readingNFC:
        backgroundColor = colorScheme.surfaceVariant;
        icon = Icons.nfc;
        title = 'Reading NFC';
        message = 'Reading chip data...';
        break;
      default:
        backgroundColor = colorScheme.surfaceVariant;
        icon = Icons.info_outline;
        title = 'In Progress';
        message = 'Follow the instructions';
    }

    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// NFC reading progress indicator
class _NFCReadingProgress extends StatefulWidget {
  const _NFCReadingProgress({Key? key}) : super(key: key);

  @override
  State<_NFCReadingProgress> createState() => _NFCReadingProgressState();
}

class _NFCReadingProgressState extends State<_NFCReadingProgress> {
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _progress,
          minHeight: 8,
        ),
        const SizedBox(height: 8),
        Text(
          'Reading chip data... ${(_progress * 100).toInt()}%',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Initial content
class _InitialContent extends StatelessWidget {
  final EKYCViewModel viewModel;

  const _InitialContent({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.person_outline, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Ready to start eKYC verification',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'First, we\'ll scan the MRZ code on your ID card',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Start MRZ scanning
                // For demo, use mock data
                viewModel.onMRZScanned(
                  const MRZData(
                    documentNumber: 'C06123456',
                    dateOfBirth: '900101',
                    dateOfExpiry: '300101',
                    firstName: 'VAN A',
                    lastName: 'NGUYEN',
                  ),
                );
              },
              child: const Text('Start MRZ Scan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// MRZ scanned content
class _MRZScannedContent extends StatelessWidget {
  final EKYCViewModel viewModel;

  const _MRZScannedContent({Key? key, required this.viewModel})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: viewModel.isNFCAvailable(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final nfcAvailable = snapshot.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (!nfcAvailable)
                  _buildError(context, 'NFC not available on this device')
                else
                  _buildNFCInstructions(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNFCInstructions(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.nfc, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          'Hold your ID card near your phone',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Keep the card steady until reading is complete',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => viewModel.readNFCChip(),
          child: const Text('Start NFC Reading'),
        ),
      ],
    );
  }
}

/// Success content
class _SuccessContent extends StatelessWidget {
  final EKYCViewModel viewModel;

  const _SuccessContent({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chipData = viewModel.chipData;
    if (chipData == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Verification Successful',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            _DataRow(label: 'Name', value: '${chipData.lastName} ${chipData.firstName}'),
            _DataRow(label: 'Document', value: chipData.documentNumber),
            _DataRow(label: 'DOB', value: chipData.dateOfBirth),
            _DataRow(label: 'Expiry', value: chipData.dateOfExpiry),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => viewModel.submitEKYC(),
              child: const Text('Submit Verification'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data row helper
class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({Key? key, required this.label, required this.value})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

/// Submitted content
class _SubmittedContent extends StatelessWidget {
  const _SubmittedContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.verified, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'eKYC completed successfully',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error content
class _ErrorContent extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorContent({
    Key? key,
    required this.message,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
