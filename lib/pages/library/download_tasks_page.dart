// 文件说明：后台任务页，Tab 一为在线书籍下载队列，Tab 二为 AI 预处理队列。
// 技术要点：DefaultTabController、DownloadTaskController、AiPreprocessTaskController。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xxread/reader_core/ai/ai_error_translator.dart';
import 'package:xxread/reader_core/ai/ai_service.dart';
import 'package:xxread/services/ai/ai_preprocess_task_controller.dart';
import 'package:xxread/services/books/book_text_extraction_service.dart';
import 'package:xxread/services/library/download_task_controller.dart';
import 'package:xxread/utils/localization_extension.dart';

class DownloadTasksPage extends StatelessWidget {
  const DownloadTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.downloadTasksTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.downloadTasksTabDownloads),
              Tab(text: l10n.libraryAiPreprocess),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DownloadTaskList(), _AiPreprocessTaskList()],
        ),
      ),
    );
  }
}

class _DownloadTaskList extends StatelessWidget {
  const _DownloadTaskList();

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<DownloadTaskController>().tasks;
    if (tasks.isEmpty) {
      return Center(child: Text(context.l10n.downloadTasksEmpty));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final progress = task.progress;
        final status = switch (task.state) {
          DownloadTaskState.queued => context.l10n.downloadTaskQueued,
          DownloadTaskState.downloading => context.l10n.downloadTaskDownloading,
          DownloadTaskState.completed => context.l10n.downloadTaskCompleted,
          DownloadTaskState.failed => context.l10n.downloadTaskFailed,
          DownloadTaskState.cancelled => context.l10n.downloadTaskCancelled,
        };
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Icon(switch (task.state) {
            DownloadTaskState.queued => Icons.schedule_rounded,
            DownloadTaskState.downloading => Icons.downloading_rounded,
            DownloadTaskState.completed => Icons.check_circle_rounded,
            DownloadTaskState.failed => Icons.error_outline_rounded,
            DownloadTaskState.cancelled => Icons.cancel_outlined,
          }),
          title: Text(
            task.book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(status),
              if (task.state == DownloadTaskState.downloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 4),
                Text(
                  task.total > 0
                      ? context.l10n.bookSourceDownloadProgress(
                          task.completed,
                          task.total,
                        )
                      : context.l10n.bookSourceFetchingCatalog,
                ),
              ],
            ],
          ),
          trailing:
              task.state == DownloadTaskState.queued ||
                  task.state == DownloadTaskState.downloading
              ? IconButton(
                  tooltip: context.l10n.downloadTaskCancel,
                  onPressed: () => context
                      .read<DownloadTaskController>()
                      .cancelTask(task.id),
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
        );
      },
    );
  }
}

class _AiPreprocessTaskList extends StatelessWidget {
  const _AiPreprocessTaskList();

  String _statusText(BuildContext context, AiPreprocessTask task) {
    final l10n = context.l10n;
    return switch (task.state) {
      AiPreprocessTaskState.queued => l10n.downloadTaskQueued,
      AiPreprocessTaskState.running => l10n.aiPreprocessTaskRunning,
      AiPreprocessTaskState.completed => l10n.libraryAiPreprocessDone,
      AiPreprocessTaskState.cancelled => l10n.downloadTaskCancelled,
      AiPreprocessTaskState.failed => l10n.libraryAiPreprocessFailed(
        _errorText(context, task.error),
      ),
    };
  }

  String _errorText(BuildContext context, Object? error) {
    if (error is AIServiceException) {
      return translateAIServiceException(context, error);
    }
    if (error is BookTextExtractionException &&
        (error.code == 'format_unsupported' ||
            error.code == 'web_unsupported')) {
      return context.l10n.libraryAiPreprocessUnsupported;
    }
    return error?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final controller = AiPreprocessTaskController();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tasks = controller.tasks;
        if (tasks.isEmpty) {
          return Center(child: Text(context.l10n.aiPreprocessTasksEmpty));
        }
        final hasFinished = tasks.any((task) => !task.isActive);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length + (hasFinished ? 1 : 0),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (hasFinished && index == tasks.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: TextButton.icon(
                    key: const ValueKey('ai-preprocess-clear-finished'),
                    onPressed: controller.clearFinished,
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: Text(context.l10n.aiPreprocessClearFinished),
                  ),
                ),
              );
            }
            final task = tasks[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              leading: Icon(switch (task.state) {
                AiPreprocessTaskState.queued => Icons.schedule_rounded,
                AiPreprocessTaskState.running => Icons.auto_awesome_rounded,
                AiPreprocessTaskState.completed => Icons.check_circle_rounded,
                AiPreprocessTaskState.failed => Icons.error_outline_rounded,
                AiPreprocessTaskState.cancelled => Icons.cancel_outlined,
              }),
              title: Text(
                task.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    _statusText(context, task),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.state == AiPreprocessTaskState.running) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: task.total > 0 ? task.done / task.total : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.libraryAiPreprocessProgress(
                        task.done,
                        task.total,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: task.isActive
                  ? IconButton(
                      tooltip: context.l10n.downloadTaskCancel,
                      onPressed: () => controller.cancelTask(task.id),
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

class BookDownloadTaskDialog extends StatelessWidget {
  const BookDownloadTaskDialog({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final task = context.select<DownloadTaskController, BookDownloadTask?>(
      (controller) => controller.taskById(taskId),
    );
    final progress = task?.progress;
    final status = switch (task?.state) {
      DownloadTaskState.queued => context.l10n.downloadTaskQueued,
      DownloadTaskState.downloading => context.l10n.downloadTaskDownloading,
      DownloadTaskState.completed => context.l10n.downloadTaskCompleted,
      DownloadTaskState.failed => context.l10n.downloadTaskFailed,
      DownloadTaskState.cancelled => context.l10n.downloadTaskCancelled,
      null => context.l10n.downloadTaskFailed,
    };
    return PopScope(
      canPop:
          task == null ||
          task.state == DownloadTaskState.completed ||
          task.state == DownloadTaskState.failed ||
          task.state == DownloadTaskState.cancelled,
      child: AlertDialog(
        title: Text(context.l10n.bookSourceDownloading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: task?.state == DownloadTaskState.failed ? 0 : progress,
            ),
            const SizedBox(height: 12),
            Text(status),
            if (task != null && task.total > 0) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.bookSourceDownloadProgress(
                  task.completed,
                  task.total,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (task != null &&
              (task.state == DownloadTaskState.queued ||
                  task.state == DownloadTaskState.downloading))
            TextButton(
              onPressed: () =>
                  context.read<DownloadTaskController>().cancelTask(task.id),
              child: Text(context.l10n.downloadTaskCancel),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.downloadContinueInBackground),
          ),
        ],
      ),
    );
  }
}
