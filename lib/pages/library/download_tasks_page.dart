import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xxread/services/library/download_task_controller.dart';
import 'package:xxread/utils/localization_extension.dart';

class DownloadTasksPage extends StatelessWidget {
  const DownloadTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<DownloadTaskController>().tasks;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.downloadTasksTitle)),
      body: tasks.isEmpty
          ? Center(child: Text(context.l10n.downloadTasksEmpty))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final task = tasks[index];
                final progress = task.progress;
                final status = switch (task.state) {
                  DownloadTaskState.queued => context.l10n.downloadTaskQueued,
                  DownloadTaskState.downloading =>
                    context.l10n.downloadTaskDownloading,
                  DownloadTaskState.completed =>
                    context.l10n.downloadTaskCompleted,
                  DownloadTaskState.failed => context.l10n.downloadTaskFailed,
                };
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: Icon(
                    switch (task.state) {
                      DownloadTaskState.queued => Icons.schedule_rounded,
                      DownloadTaskState.downloading =>
                        Icons.downloading_rounded,
                      DownloadTaskState.completed => Icons.check_circle_rounded,
                      DownloadTaskState.failed => Icons.error_outline_rounded,
                    },
                  ),
                  title: Text(task.book.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
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
                );
              },
            ),
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
      null => context.l10n.downloadTaskFailed,
    };
    return PopScope(
      canPop: false,
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.downloadContinueInBackground),
          ),
        ],
      ),
    );
  }
}
