import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../errors/app_error.dart';
import '../../../scheduler/services/scheduler_input.dart';
import '../controllers/news_controller.dart';
import '../providers/news_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _keywordsController;

  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _notificationsEnabled = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _keywordsController = TextEditingController();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _loadFromState(NewsSchedulerInput settings) async {
    if (_initialized) return;
    setState(() {
      _apiKeyController.text = settings.apiKey;
      _keywordsController.text = settings.keywords.join(',');
      _selectedTime = TimeOfDay(
        hour: settings.scheduledHour,
        minute: settings.scheduledMinute,
      );
      _notificationsEnabled = settings.notificationEnabled;
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(newsSchedulerSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: settingsAsync.when(
        data: (settings) {
          _loadFromState(settings);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Gemini APIキー',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keywordsController,
                decoration: const InputDecoration(
                  labelText: '検索キーワード（カンマ区切り）',
                  border: OutlineInputBorder(),
                  helperText: '例: AI,テック,プレス',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _notificationsEnabled,
                title: const Text('通知を有効化'),
                onChanged: (value) => setState(() {
                  _notificationsEnabled = value;
                }),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('実行時刻'),
                subtitle: Text(_selectedTime.format(context)),
                trailing: const Icon(Icons.schedule),
                onTap: _pickTime,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final notifier = ref.read(newsActionControllerProvider.notifier);
                  final keywords = _keywordsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  final nextSettings = NewsSchedulerInput(
                    apiKey: _apiKeyController.text.trim(),
                    keywords: keywords,
                    scheduledHour: _selectedTime.hour,
                    scheduledMinute: _selectedTime.minute,
                    notificationEnabled: _notificationsEnabled,
                    failureCount: settings.failureCount,
                  );

                  await notifier.updateSettings(nextSettings);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('保存して再スケジュール'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.read(newsActionControllerProvider.notifier).manualFetch(),
                child: const Text('今すぐ実行'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('設定読込エラー: ${_errorMessage(error)}'),
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppError) {
      return error.userMessage;
    }
    return error.toString();
  }
}

