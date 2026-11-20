import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/env_config.dart';

/// Screen displayed when Supabase credentials are missing.
class UnconfiguredScreen extends StatelessWidget {
  const UnconfiguredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Required')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.settings_suggest_rounded,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Supabase Configuration Needed',
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${EnvConfig.appName} requires your Supabase project credentials to connect to the backend.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '1. Create an env.json file in the project root:',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const SelectableText(
                        '{\n'
                        '  "SUPABASE_URL": "https://your-project.supabase.co",\n'
                        '  "SUPABASE_ANON_KEY": "your-anon-key"\n'
                        '}',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '2. Run the application with:',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: SelectableText(
                              'flutter run --dart-define-from-file=env.json',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            onPressed: () {
                              Clipboard.setData(
                                const ClipboardData(
                                  text: 'flutter run --dart-define-from-file=env.json',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Command copied to clipboard'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
