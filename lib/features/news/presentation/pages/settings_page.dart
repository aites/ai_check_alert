import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../errors/app_error.dart';
import '../../../scheduler/services/scheduler_input.dart';
import '../controllers/news_controller.dart';
import '../providers/news_providers.dart';

/// Settings page for API key, topics and notification schedule.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiKeyController;
  late final TextEditingController _keywordsController;

  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _notificationsEnabled = true;
  bool _obscureApiKey = true;
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

  void _loadFromState(NewsSchedulerInput settings) {
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

  Future<bool> _handleWillPop(NewsSchedulerInput settings) async {
    if (!_hasUnsavedChanges(settings)) {
      return true;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('変更を破棄しますか？'),
          content: const Text('保存していない変更があります。このまま戻ると内容は失われます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('破棄して戻る'),
            ),
          ],
        );
      },
    );

    return discard ?? false;
  }

  bool _hasUnsavedChanges(NewsSchedulerInput settings) {
    final current = _buildCurrentSettings(settings.failureCount);
    return current.apiKey != settings.apiKey ||
        current.scheduledHour != settings.scheduledHour ||
        current.scheduledMinute != settings.scheduledMinute ||
        current.notificationEnabled != settings.notificationEnabled ||
        _keywordSignature(current.keywords) !=
            _keywordSignature(settings.keywords);
  }

  NewsSchedulerInput _buildCurrentSettings(int failureCount) {
    final keywords = _keywordsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return NewsSchedulerInput(
      apiKey: _apiKeyController.text.trim(),
      keywords: keywords,
      scheduledHour: _selectedTime.hour,
      scheduledMinute: _selectedTime.minute,
      notificationEnabled: _notificationsEnabled,
      failureCount: failureCount,
    );
  }

  String _keywordSignature(List<String> keywords) {
    return keywords.map((e) => e.trim()).where((e) => e.isNotEmpty).join('|');
  }

  Future<void> _saveSettings(NewsSchedulerInput settings) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final notifier = ref.read(newsActionControllerProvider.notifier);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final keywords = _keywordsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final nextSettings = NewsSchedulerInput(
      apiKey: _apiKeyController.text.trim(),
      keywords: keywords,
      scheduledHour: _selectedTime.hour,
      scheduledMinute: _selectedTime.minute,
      notificationEnabled: _notificationsEnabled,
      failureCount: settings.failureCount,
    );

    try {
      await notifier.updateSettings(nextSettings);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('設定を保存しました。次回実行スケジュールを更新しました。')),
      );
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('設定保存に失敗しました: ${_errorMessage(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(newsSchedulerSettingsProvider);

    return settingsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('設定')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('設定')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('設定読込エラー: ${_errorMessage(error)}'),
          ),
        ),
      ),
      data: (settings) {
        _loadFromState(settings);

        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            final navigator = Navigator.of(context);
            final canLeave = await _handleWillPop(settings);
            if (!mounted || !canLeave) {
              return;
            }
            navigator.pop(result);
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('設定')),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      labelText: 'Gemini APIキー',
                      border: const OutlineInputBorder(),
                      helperText: '未入力時は .env の GEMINI_API_KEY を使用します',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureApiKey = !_obscureApiKey;
                          });
                        },
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _keywordsController,
                    decoration: const InputDecoration(
                      labelText: '検索キーワード（カンマ区切り）',
                      border: OutlineInputBorder(),
                      helperText: '例: AI,テック,プレス',
                    ),
                    validator: (value) {
                      final hasKeyword = (value ?? '')
                          .split(',')
                          .map((e) => e.trim())
                          .any((e) => e.isNotEmpty);
                      if (!hasKeyword) {
                        return '最低1つはキーワードを設定してください。';
                      }
                      return null;
                    },
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
                    onPressed: () => _saveSettings(settings),
                    child: const Text('保存して再スケジュール'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(newsActionControllerProvider.notifier)
                        .manualFetch(),
                    child: const Text('今すぐ実行'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _errorMessage(Object error) {
    if (error is AppError) {
      return error.userMessage;
    }
    return error.toString();
  }
}
