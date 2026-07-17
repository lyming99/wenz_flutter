import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _defaultPlanPath = 'docs/advanced_feature_development_plan.md';
const _totalAdvTaskFallback = 30;

Future<void> main(List<String> args) async {
  configureConsoleEncoding();

  final options = Options.parse(args);

  if (options.help) {
    stdout.write(Options.usage);
    return;
  }

  final repoRoot = options.repoRoot.absolute.normalize();
  final planFile = resolvePath(repoRoot, options.planPath);

  if (!planFile.existsSync()) {
    fail('Plan file does not exist: ${planFile.path}');
  }

  if (!options.dryRun) {
    await ensureCodexAvailable(options.codexCommand);
  }
  options.logDir.createSync(recursive: true);

  final schemaFile =
      File(joinPath(options.logDir.path, 'completion-schema.json'));
  schemaFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(completionSchema),
    encoding: utf8,
  );

  var planSnapshot = PlanSnapshot.read(planFile);
  final totalTasks = planSnapshot.allTaskIds.isEmpty
      ? _totalAdvTaskFallback
      : planSnapshot.allTaskIds.length;
  var iteration = 0;
  var consecutiveFailures = 0;
  Set<String>? lastRemainingIds;

  stdout.writeln(
    'Starting plan loop. Iterations: ${options.maxIterations <= 0 ? 'unlimited' : options.maxIterations}; logs: ${options.logDir.path}',
  );

  while (true) {
    if (options.maxIterations > 0 && iteration >= options.maxIterations) {
      stdout.writeln('Stopped: reached max iterations before completion.');
      exitCode = 2;
      return;
    }

    iteration++;
    final runDir = Directory(
      joinPath(
        options.logDir.path,
        'iteration-${iteration.toString().padLeft(4, '0')}-${timestampForPath()}',
      ),
    )..createSync(recursive: true);

    planSnapshot = PlanSnapshot.read(planFile);
    final target = planSnapshot.chooseTarget(lastRemainingIds);
    stdout.writeln(
      '[${clock()}] iteration $iteration target: ${target?.label ?? 'auto'}',
    );

    final advancePrompt = buildAdvancePrompt(planFile, target);
    final checkPrompt = buildCheckPrompt(planFile);

    final advancePromptFile = File(joinPath(runDir.path, 'advance-prompt.txt'))
      ..writeAsStringSync(advancePrompt, encoding: utf8);
    final checkPromptFile = File(joinPath(runDir.path, 'check-prompt.txt'))
      ..writeAsStringSync(checkPrompt, encoding: utf8);
    final advanceLastMessageFile =
        File(joinPath(runDir.path, 'advance-last-message.txt'));
    final checkLastMessageFile =
        File(joinPath(runDir.path, 'check-last-message.json'));
    final advanceOutputFile =
        File(joinPath(runDir.path, 'advance-codex-output.log'));
    final checkOutputFile =
        File(joinPath(runDir.path, 'check-codex-output.log'));

    try {
      await invokeCodex(
        options: options,
        repoRoot: repoRoot,
        prompt: advancePrompt,
        phase: 'iteration $iteration: advancing plan',
        outputFile: advanceOutputFile,
        lastMessageFile: advanceLastMessageFile,
        timeout: Duration(minutes: options.advanceTimeoutMinutes),
        extraArgs: options.dangerous
            ? const ['--dangerously-bypass-approvals-and-sandbox']
            : ['--sandbox', options.advanceSandbox],
      );

      if (!options.dryRun) {
        printLastMessageSummary(advanceLastMessageFile, options);
      }

      var validation = await runHostValidations(
        options: options,
        repoRoot: repoRoot,
        runDir: runDir,
        label: 'after-advance',
      );

      for (var repairAttempt = 1;
          !validation.success && repairAttempt <= options.repairAttempts;
          repairAttempt++) {
        final repairPrompt = buildRepairPrompt(
          planFile: planFile,
          target: target,
          validation: validation,
        );
        File(joinPath(runDir.path, 'repair-$repairAttempt-prompt.txt'))
            .writeAsStringSync(repairPrompt, encoding: utf8);
        final repairLastMessageFile = File(
            joinPath(runDir.path, 'repair-$repairAttempt-last-message.txt'));
        final repairOutputFile = File(
            joinPath(runDir.path, 'repair-$repairAttempt-codex-output.log'));

        await invokeCodex(
          options: options,
          repoRoot: repoRoot,
          prompt: repairPrompt,
          phase:
              'iteration $iteration: repairing validation errors ($repairAttempt/${options.repairAttempts})',
          outputFile: repairOutputFile,
          lastMessageFile: repairLastMessageFile,
          timeout: Duration(minutes: options.advanceTimeoutMinutes),
          extraArgs: options.dangerous
              ? const ['--dangerously-bypass-approvals-and-sandbox']
              : ['--sandbox', options.advanceSandbox],
        );
        if (!options.dryRun) {
          printLastMessageSummary(repairLastMessageFile, options);
        }
        validation = await runHostValidations(
          options: options,
          repoRoot: repoRoot,
          runDir: runDir,
          label: 'repair-$repairAttempt',
        );
      }

      if (!validation.success) {
        if (target != null) {
          lastRemainingIds = {target.id};
        }
        throw StateError(
          'host validation failed after ${options.repairAttempts} repair attempt(s). Log: ${validation.logFile.path}',
        );
      }

      await invokeCodex(
        options: options,
        repoRoot: repoRoot,
        prompt: checkPrompt,
        phase: 'iteration $iteration: checking completion',
        outputFile: checkOutputFile,
        lastMessageFile: checkLastMessageFile,
        timeout: Duration(minutes: options.checkTimeoutMinutes),
        extraArgs: [
          '--sandbox',
          'read-only',
          '--output-schema',
          schemaFile.path,
        ],
      );

      if (options.dryRun) {
        stdout.writeln('Dry run finished. Files: ${runDir.path}');
        stdout.writeln(
            'Prompts: ${advancePromptFile.path}; ${checkPromptFile.path}');
        return;
      }

      final result =
          CompletionResult.parse(checkLastMessageFile.readAsStringSync(
        encoding: utf8,
      ));
      final remainingIds = result.remainingIds.toSet();
      final completedCount = result.complete
          ? totalTasks
          : (totalTasks - remainingIds.length).clamp(0, totalTasks);
      final nextId = planSnapshot.allTaskIds.firstWhere(
        remainingIds.contains,
        orElse: () => remainingIds.isEmpty ? '' : remainingIds.first,
      );

      consecutiveFailures = 0;

      if (result.complete) {
        stdout.writeln('[${clock()}] complete: ${result.reason}');
        return;
      }

      lastRemainingIds = remainingIds;
      final nextText = nextId.isEmpty ? '' : '; next: $nextId';
      final reason = compactLine(result.reason, maxLength: 160);
      if (reason.isNotEmpty) {
        stdout.writeln('  Check: $reason');
      }
      stdout.writeln(
        '[${clock()}] progress: $completedCount/$totalTasks complete; remaining: ${remainingIds.length}$nextText',
      );
    } catch (error) {
      consecutiveFailures++;
      stderr.writeln(
        '[${clock()}] warning: $error; consecutive failures: $consecutiveFailures',
      );

      if (options.failureLimit > 0 &&
          consecutiveFailures >= options.failureLimit) {
        fail('Stopped after $consecutiveFailures consecutive failures.');
      }
    }

    if (options.delaySeconds > 0) {
      await Future<void>.delayed(Duration(seconds: options.delaySeconds));
    }
  }
}

Future<void> ensureCodexAvailable(String command) async {
  try {
    final result = await Process.run(
      command,
      const ['--version'],
      runInShell: Platform.isWindows,
    );

    if (result.exitCode != 0) {
      fail('codex command failed: $command --version');
    }
  } on ProcessException catch (error) {
    fail('Cannot run codex command "$command": ${error.message}');
  }
}

Future<void> invokeCodex({
  required Options options,
  required Directory repoRoot,
  required String prompt,
  required String phase,
  required File outputFile,
  required File lastMessageFile,
  required Duration timeout,
  required List<String> extraArgs,
}) async {
  stdout.writeln('[${clock()}] $phase');

  if (options.dryRun) {
    stdout.writeln('  dry run: codex-cli was not invoked');
    return;
  }

  final args = <String>[
    'exec',
    '--cd',
    repoRoot.path,
    '--color',
    'never',
    '-o',
    lastMessageFile.path,
    if (options.model.isNotEmpty) ...['-m', options.model],
    ...extraArgs,
    '-',
  ];

  final process = await Process.start(
    options.codexCommand,
    args,
    runInShell: Platform.isWindows,
  );

  process.stdin.encoding = utf8;
  process.stdin.write(prompt);
  await process.stdin.close();

  final sink = outputFile.openWrite(encoding: utf8);
  final activity = CodexActivityPrinter(
    maxLines: options.activityLines,
    showActivity: options.showCodexActivity,
    showTail: options.showCodexTail,
    tailInterval: Duration(milliseconds: options.tailIntervalMs),
  );
  final stdoutDone = pipeProcessStream(
    process.stdout,
    sink,
    options: options,
    activity: activity,
    isError: false,
  );
  final stderrDone = pipeProcessStream(
    process.stderr,
    sink,
    options: options,
    activity: activity,
    isError: true,
  );

  var timedOut = false;
  final code = await process.exitCode.timeout(
    timeout,
    onTimeout: () async {
      timedOut = true;
      process.kill();
      return process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
    },
  );
  await Future.wait([stdoutDone, stderrDone]);
  await sink.close();

  if (timedOut) {
    throw TimeoutException(
      'codex phase timed out after ${timeout.inMinutes} minute(s). Log: ${outputFile.path}',
      timeout,
    );
  }

  if (code != 0) {
    throw StateError(
        'codex failed with exit code $code. Log: ${outputFile.path}');
  }
}

Future<void> pipeProcessStream(
  Stream<List<int>> source,
  IOSink sink, {
  required Options options,
  required CodexActivityPrinter activity,
  required bool isError,
}) {
  final completer = Completer<void>();
  var pendingLine = '';

  void flushLine(String line) {
    if (options.showCodexOutput) {
      return;
    }
    if (!options.showCodexActivity && !options.showCodexTail) {
      return;
    }
    activity.offer(line);
  }

  source.transform(const Utf8Decoder(allowMalformed: true)).listen(
        (chunk) {
          sink.write(chunk);
          if (options.showCodexOutput) {
            if (isError) {
              stderr.write(chunk);
            } else {
              stdout.write(chunk);
            }
            return;
          }

          pendingLine += chunk;
          while (true) {
            final newlineIndex = pendingLine.indexOf('\n');
            if (newlineIndex < 0) {
              break;
            }
            final line = pendingLine.substring(0, newlineIndex);
            pendingLine = pendingLine.substring(newlineIndex + 1);
            flushLine(line);
          }
        },
        onError: completer.completeError,
        onDone: () {
          if (pendingLine.trim().isNotEmpty) {
            flushLine(pendingLine);
          }
          completer.complete();
        },
        cancelOnError: true,
      );
  return completer.future;
}

String buildAdvancePrompt(File planFile, PlanTarget? target) {
  final targetLines = target == null
      ? const [
          'Dart 控制器本轮没有选出明确目标，请从计划中选择下一个未完成任务。',
        ]
      : [
          'Dart 控制器为本轮选择的目标任务：',
          '- ID：${target.id}',
          if (target.title.isNotEmpty) '- 标题：${target.title}',
        ];

  return [
    '你是当前仓库的自动开发推进者。',
    '请读取并执行以下计划文件：',
    planFile.path,
    '',
    ...targetLines,
    '',
    '本轮只推进一个清晰、可验证的增量。',
    '优先完成 Dart 控制器选中的目标任务；如果该任务已经完成，再选择计划中最高优先级、推荐顺序最靠前的未完成 ADV 任务。',
    '',
    '工作要求：',
    '- 不要重做已经标记为 [done]，或已经在“当前进度”中明确完成的任务。',
    '- 实现必要代码、测试、example 或文档更新，让该增量尽可能满足计划中的验收标准。',
    '- 完成后更新 docs/advanced_feature_development_plan.md、docs/advanced_feature_matrix.md，以及相关 API、架构或验收文档。',
    '- 运行与改动相关的最小验证；如果改动面较大，再运行 flutter analyze 和 flutter test。',
    '- 如果所有 ADV 任务已经完成，不要做无意义改动，只在最终回复中说明已经完成。',
    '- 如果被外部条件阻塞，请在最终回复中说明阻塞原因、已完成内容和下一步建议。',
    '',
    '命令与输出约束：',
    '- 在 Windows/PowerShell 中读取或写入中文文件时必须显式使用 UTF-8，例如 Get-Content -Encoding UTF8、Set-Content -Encoding UTF8。',
    '- 运行 PowerShell 命令前优先设置 [Console]::OutputEncoding = [System.Text.Encoding]::UTF8。',
    '- 不要把计划全文、源码全文、测试文件全文或完整 diff 输出到终端。',
    '- 不要运行会输出大段补丁的命令，例如裸 git diff 或 git show；如需了解状态，只用 git status --short 或针对性读取少量片段。',
    '- 工具输出应保持短小，只输出当前判断所需的摘要或匹配行。',
    '',
    '最终回复要求：',
    '- 使用中文回复。',
    '- 像 GUI 活动摘要一样简洁，只包含关键结果、验证情况、阻塞或下一步。',
    '- 不要包含 diff、代码块、文件具体内容或很长的修改文件列表。',
  ].join('\n');
}

String buildCheckPrompt(File planFile) {
  return [
    '只读检查当前仓库，不要修改任何文件。',
    '',
    '请根据计划文件和当前仓库状态，判断 advanced feature 任务是否已经全部完成：',
    planFile.path,
    '',
    '判定规则：',
    '- 只有任务列表中 ADV-001 到 ADV-030 全部完成时，complete 才能为 true。',
    '- 如果只有代码存在，但计划、功能矩阵、相关文档或必要测试明显缺失，则该任务不算完成。',
    '- 如果仍有任务未完成，请把任务 ID 列入 remaining_ids。',
    '- reason 必须是适合终端进度展示的简短中文说明，不要包含 diff、文件具体内容或很长的文件列表。',
    '- 在 Windows/PowerShell 中读取中文文件时必须显式使用 UTF-8，例如 Get-Content -Encoding UTF8。',
    '- 不要输出计划全文、源码全文或完整 diff；只做必要的只读摘要检查。',
    '- 输出必须严格符合给定 JSON schema，不要附加 Markdown 或解释性文本。',
  ].join('\n');
}

String buildRepairPrompt({
  required File planFile,
  required PlanTarget? target,
  required ValidationResult validation,
}) {
  return [
    '你是当前仓库的自动修复执行者。',
    '上一轮推进后，宿主机侧验证命令失败。请只修复这些验证错误，不要切换到新的 ADV 任务。',
    '',
    '计划文件：',
    planFile.path,
    '',
    if (target != null) ...[
      '当前必须继续修复的目标任务：',
      '- ID：${target.id}',
      if (target.title.isNotEmpty) '- 标题：${target.title}',
      '',
    ],
    '失败的验证命令：',
    validation.failedCommand ?? 'unknown',
    '',
    '验证输出摘要：',
    validation.outputForPrompt(maxChars: 10000),
    '',
    '修复要求：',
    '- 优先修复编译、analyze、test 报错。',
    '- 不要新增无关功能，不要推进下一个 ADV 任务。',
    '- 不要输出完整 diff、源码全文或长文件列表。',
    '- Windows/PowerShell 读取中文文件时必须显式使用 UTF-8。',
    '- 修复后用中文简短说明修复点和建议复验命令。',
  ].join('\n');
}

void printLastMessageSummary(File file, Options options) {
  if (!file.existsSync()) {
    stdout.writeln('  Codex: 未生成最终摘要，完整输出见日志');
    return;
  }

  final description = CodexKeyDescription.extract(
    file.readAsStringSync(encoding: utf8),
    maxLines: options.summaryLines,
  );
  description.printToStdout();
}

Future<ValidationResult> runHostValidations({
  required Options options,
  required Directory repoRoot,
  required Directory runDir,
  required String label,
}) async {
  if (options.dryRun || options.validationCommands.isEmpty) {
    return ValidationResult.success(
      logFile: File(joinPath(runDir.path, 'validation-$label.log')),
    );
  }

  final logFile = File(joinPath(runDir.path, 'validation-$label.log'));
  final sink = logFile.openWrite(encoding: utf8);
  try {
    for (final command in options.validationCommands) {
      stdout.writeln('[${clock()}] host validation: $command');
      sink.writeln('> $command');
      final result = await runShellCommand(
        command,
        workingDirectory: repoRoot,
        timeout: Duration(minutes: options.validationTimeoutMinutes),
      );
      sink
        ..writeln('exitCode: ${result.exitCode}')
        ..writeln(result.output)
        ..writeln('');

      if (result.exitCode != 0) {
        stdout.writeln('  Validate: failed ($command). Log: ${logFile.path}');
        return ValidationResult.failure(
          logFile: logFile,
          failedCommand: command,
          output: result.output,
        );
      }

      stdout.writeln('  Validate: passed ($command)');
    }

    return ValidationResult.success(logFile: logFile);
  } finally {
    await sink.close();
  }
}

Future<ShellCommandResult> runShellCommand(
  String command, {
  required Directory workingDirectory,
  required Duration timeout,
}) async {
  final executable = Platform.isWindows ? 'cmd.exe' : '/bin/sh';
  final args = Platform.isWindows
      ? ['/d', '/s', '/c', 'chcp 65001>nul && $command']
      : ['-lc', command];

  final process = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory.path,
    runInShell: false,
  );

  final output = StringBuffer();
  final stdoutDone = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .listen(output.write)
      .asFuture<void>();
  final stderrDone = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .listen(output.write)
      .asFuture<void>();

  var timedOut = false;
  final code = await process.exitCode.timeout(
    timeout,
    onTimeout: () async {
      timedOut = true;
      process.kill();
      return process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
    },
  );
  await Future.wait([stdoutDone, stderrDone]);

  if (timedOut) {
    output.writeln(
      'Command timed out after ${timeout.inMinutes} minute(s).',
    );
  }

  return ShellCommandResult(exitCode: code, output: output.toString());
}

File resolvePath(Directory repoRoot, String path) {
  final file = File(path);
  if (file.isAbsolute) {
    return file.absolute.normalize();
  }
  return File(joinPath(repoRoot.path, path)).absolute.normalize();
}

String joinPath(String left, String right) {
  if (left.isEmpty) {
    return right;
  }
  final separator = Platform.pathSeparator;
  return left.endsWith(separator) ? '$left$right' : '$left$separator$right';
}

String timestampForPath() {
  final now = DateTime.now();
  return [
    now.year.toString().padLeft(4, '0'),
    now.month.toString().padLeft(2, '0'),
    now.day.toString().padLeft(2, '0'),
    '-',
    now.hour.toString().padLeft(2, '0'),
    now.minute.toString().padLeft(2, '0'),
    now.second.toString().padLeft(2, '0'),
  ].join();
}

String clock() {
  final now = DateTime.now();
  return [
    now.hour.toString().padLeft(2, '0'),
    now.minute.toString().padLeft(2, '0'),
    now.second.toString().padLeft(2, '0'),
  ].join(':');
}

void fail(String message) {
  stderr.writeln(message);
  exit(1);
}

void configureConsoleEncoding() {
  try {
    stdout.encoding = utf8;
    stderr.encoding = utf8;
  } catch (_) {
    // Some redirected environments do not allow changing stdio encoding.
  }
}

String compactLine(String value, {int maxLength = 180}) {
  final normalized = value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[\u0000-\u001f]'), ' ')
      .trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength - 3).trimRight()}...';
}

extension NormalizedDirectory on Directory {
  Directory normalize() {
    return Directory(File(path).absolute.normalize().path);
  }
}

extension NormalizedFile on File {
  File normalize() {
    return File(Uri.file(path).normalizePath().toFilePath());
  }
}

class ShellCommandResult {
  const ShellCommandResult({
    required this.exitCode,
    required this.output,
  });

  final int exitCode;
  final String output;
}

class ValidationResult {
  const ValidationResult._({
    required this.success,
    required this.logFile,
    required this.failedCommand,
    required this.output,
  });

  factory ValidationResult.success({required File logFile}) {
    return ValidationResult._(
      success: true,
      logFile: logFile,
      failedCommand: null,
      output: '',
    );
  }

  factory ValidationResult.failure({
    required File logFile,
    required String failedCommand,
    required String output,
  }) {
    return ValidationResult._(
      success: false,
      logFile: logFile,
      failedCommand: failedCommand,
      output: output,
    );
  }

  final bool success;
  final File logFile;
  final String? failedCommand;
  final String output;

  String outputForPrompt({required int maxChars}) {
    final normalized = output.trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return normalized.substring(normalized.length - maxChars);
  }
}

class PlanSnapshot {
  const PlanSnapshot({
    required this.allTaskIds,
    required this.doneIds,
    required this.explicitNextId,
    required this.titlesById,
  });

  final List<String> allTaskIds;
  final Set<String> doneIds;
  final String? explicitNextId;
  final Map<String, String> titlesById;

  static PlanSnapshot read(File planFile) {
    final text = planFile.readAsStringSync(encoding: utf8);
    final allIds = <String>[];
    final seen = <String>{};
    final done = <String>{};
    final titles = <String, String>{};

    for (final line in const LineSplitter().convert(text)) {
      final ids = RegExp(r'\bADV-\d{3}\b')
          .allMatches(line)
          .map((match) => match.group(0)!)
          .toList(growable: false);

      for (final id in ids) {
        if (seen.add(id)) {
          allIds.add(id);
        }
      }

      final lower = line.toLowerCase();
      final doneLine = lower.contains('[done]') ||
          line.contains('已完成') ||
          line.contains('最近完成项') ||
          lower.contains('completed');
      final notDoneLine =
          line.contains('未完成') || lower.contains('not complete');

      if (doneLine && !notDoneLine) {
        done.addAll(ids);
      }

      final tableTitle = _parseTaskTitle(line);
      if (tableTitle != null) {
        titles[tableTitle.id] = tableTitle.title;
      }
    }

    final explicitNext =
        RegExp(r'下一项(?:为|是)[^\n]*(ADV-\d{3})').firstMatch(text)?.group(1);

    return PlanSnapshot(
      allTaskIds: allIds,
      doneIds: done,
      explicitNextId: explicitNext,
      titlesById: titles,
    );
  }

  PlanTarget? chooseTarget(Set<String>? aiRemainingIds) {
    final remaining = aiRemainingIds;
    if (remaining != null && remaining.isNotEmpty) {
      for (final id in allTaskIds) {
        if (remaining.contains(id)) {
          return PlanTarget(id: id, title: titlesById[id] ?? '');
        }
      }
      final first = remaining.first;
      return PlanTarget(id: first, title: titlesById[first] ?? '');
    }

    final explicit = explicitNextId;
    if (explicit != null && !doneIds.contains(explicit)) {
      return PlanTarget(id: explicit, title: titlesById[explicit] ?? '');
    }

    for (final id in allTaskIds) {
      if (!doneIds.contains(id)) {
        return PlanTarget(id: id, title: titlesById[id] ?? '');
      }
    }

    return null;
  }

  static PlanTarget? _parseTaskTitle(String line) {
    if (!line.trimLeft().startsWith('|') || !line.contains('ADV-')) {
      return null;
    }

    final cells = line
        .split('|')
        .map((cell) => cell.trim())
        .where((cell) => cell.isNotEmpty)
        .toList(growable: false);

    if (cells.length < 4) {
      return null;
    }

    final idMatch = RegExp(r'\bADV-\d{3}\b').firstMatch(cells[0]);
    if (idMatch == null) {
      return null;
    }

    return PlanTarget(id: idMatch.group(0)!, title: cells[3]);
  }
}

class PlanTarget {
  const PlanTarget({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;

  String get label => title.isEmpty ? id : '$id $title';
}

class CodexActivityPrinter {
  CodexActivityPrinter({
    required this.maxLines,
    required this.showActivity,
    required this.showTail,
    required this.tailInterval,
  });

  final int maxLines;
  final bool showActivity;
  final bool showTail;
  final Duration tailInterval;
  final _recent = <String>{};
  var _shown = 0;
  var _omittedNoticeShown = false;
  var _skippingUserEcho = false;
  DateTime? _lastTailAt;
  String? _lastTailLine;

  void offer(String rawLine) {
    final marker = _cleanMarker(rawLine);
    if (marker == 'user') {
      _skippingUserEcho = true;
      return;
    }

    if (_skippingUserEcho) {
      if (_startsModelOutput(marker)) {
        _skippingUserEcho = false;
      } else {
        return;
      }
    }

    final line = _cleanBaseLine(rawLine);
    if (line == null) {
      return;
    }

    var printedActivity = false;
    if (showActivity && _isActivityLine(line)) {
      printedActivity = _printActivity(line);
    }

    if (showTail && !printedActivity) {
      _printTail(line);
    }
  }

  bool _printActivity(String line) {
    if (maxLines <= 0) {
      return false;
    }

    if (_shown >= maxLines) {
      if (!_omittedNoticeShown) {
        stdout.writeln('  Activity: ... 后续活动已折叠，完整内容见日志');
        _omittedNoticeShown = true;
      }
      return false;
    }

    if (!_recent.add('activity:$line')) {
      return false;
    }
    _shown++;
    stdout.writeln('  Activity: $line');
    return true;
  }

  void _printTail(String line) {
    final now = DateTime.now();
    if (_lastTailLine == line) {
      return;
    }
    if (_lastTailAt != null && now.difference(_lastTailAt!) < tailInterval) {
      return;
    }

    _lastTailAt = now;
    _lastTailLine = line;
    stdout.writeln('  Tail: $line');
  }

  static String _cleanMarker(String rawLine) {
    return rawLine
        .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
        .replaceAll('\r', '')
        .trim();
  }

  static bool _startsModelOutput(String line) {
    return line == 'codex' ||
        line == 'exec' ||
        line.startsWith('**') ||
        line.startsWith('Planning ') ||
        line.startsWith('我');
  }

  static String? _cleanBaseLine(String rawLine) {
    var line = rawLine
        .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
        .replaceAll('\r', '')
        .trim();

    if (line.isEmpty) {
      return null;
    }

    line = line
        .replaceAll(RegExp(r'^[>•*+\-\s]+'), '')
        .replaceAll(RegExp(r'^[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]\s*'), '')
        .trim();

    if (line.isEmpty || _looksLikeNoise(line) || _looksLikeFileContent(line)) {
      return null;
    }

    return compactLine(line, maxLength: 180);
  }

  static bool _isActivityLine(String line) {
    final lower = line.toLowerCase();
    final keywords = <String>[
      'thinking',
      'plan',
      'running',
      'exec',
      'command',
      'test',
      'analyze',
      'flutter',
      'dart',
      'complete',
      'completed',
      'summary',
      'verification',
      'blocked',
      '思考',
      '计划',
      '执行',
      '运行',
      '命令',
      '测试',
      '分析',
      '检查',
      '验证',
      '完成',
      '阻塞',
      '摘要',
      '推进',
    ];

    return keywords.any(lower.contains);
  }

  static bool _looksLikeNoise(String line) {
    final lower = line.toLowerCase();
    if (lower == 'codex' ||
        lower == 'exec' ||
        lower == 'user' ||
        lower.startsWith('openai codex') ||
        lower.startsWith('workdir:') ||
        lower.startsWith('model:') ||
        lower.startsWith('provider:') ||
        lower.startsWith('approval:') ||
        lower.startsWith('sandbox:') ||
        lower.startsWith('reasoning effort:') ||
        lower.startsWith('reasoning summaries:') ||
        lower.startsWith('session id:') ||
        lower.startsWith('usage:') ||
        lower.startsWith('options:') ||
        lower.startsWith('warning:')) {
      return true;
    }

    return RegExp(r'^\d+:\d+(:\d+)?$').hasMatch(line) ||
        RegExp(r'^[=\-_]{3,}$').hasMatch(line);
  }

  static bool _looksLikeFileContent(String line) {
    final lower = line.toLowerCase();
    if (line.startsWith('::') ||
        line.startsWith('diff --git') ||
        line.startsWith('@@') ||
        line.startsWith('--- ') ||
        line.startsWith('+++ ') ||
        line.startsWith('+') ||
        line.startsWith('-') && !line.startsWith('- ') ||
        lower.startsWith('import ') ||
        lower.startsWith('class ') ||
        lower.startsWith('final ') ||
        lower.startsWith('const ') ||
        lower.startsWith('return ') ||
        lower.startsWith('if ') ||
        lower.startsWith('for ') ||
        line == '}' ||
        line == '{') {
      return true;
    }

    if (RegExp(
      r'^(lib|test|docs|tool|scripts|example)[/\\].+',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    final codePunctuationCount = RegExp(r'[{}();=<>]').allMatches(line).length;
    return codePunctuationCount >= 5;
  }
}

class CodexKeyDescription {
  const CodexKeyDescription(this.lines);

  final List<String> lines;

  static CodexKeyDescription extract(String text, {required int maxLines}) {
    final withoutCode = text.replaceAll(
      RegExp(r'```[\s\S]*?```', multiLine: true),
      ' ',
    );
    final lines = <String>[];

    for (final rawLine in const LineSplitter().convert(withoutCode)) {
      final cleaned = _cleanSummaryLine(rawLine);
      if (cleaned.isEmpty || _looksLikeFileDetail(cleaned)) {
        continue;
      }
      lines.add(compactLine(cleaned));
      if (lines.length >= maxLines) {
        break;
      }
    }

    if (lines.isEmpty) {
      final fallback = compactLine(withoutCode, maxLength: 180);
      if (fallback.isNotEmpty) {
        lines.add(fallback);
      }
    }

    return CodexKeyDescription(lines);
  }

  void printToStdout() {
    if (lines.isEmpty) {
      return;
    }

    stdout.writeln('  Codex: ${lines.first}');
    for (final line in lines.skip(1)) {
      stdout.writeln('         $line');
    }
  }

  static String _cleanSummaryLine(String line) {
    return line
        .replaceAllMapped(RegExp(r'\[(.*?)\]\([^)]+\)'), (match) {
          return match.group(1) ?? '';
        })
        .replaceAll(RegExp(r'^#{1,6}\s*'), '')
        .replaceAll(RegExp(r'^[-*+]\s+'), '')
        .replaceAll(RegExp(r'^\d+[.)]\s+'), '')
        .replaceAll('`', '')
        .trim();
  }

  static bool _looksLikeFileDetail(String line) {
    final lower = line.toLowerCase();
    if (line.startsWith('::') ||
        line.startsWith('diff --git') ||
        line.startsWith('@@') ||
        line.startsWith('--- ') ||
        line.startsWith('+++ ')) {
      return true;
    }

    const noisyPrefixes = [
      'files changed',
      'changed files',
      'modified files',
      'updated files',
      'files:',
      'diff:',
      '修改文件',
      '变更文件',
      '文件变更',
    ];
    if (noisyPrefixes.any(lower.startsWith)) {
      return true;
    }

    return RegExp(
      r'^(lib|test|docs|tool|scripts|example)[/\\].+\.(dart|md|yaml|json|ps1|txt)$',
      caseSensitive: false,
    ).hasMatch(line);
  }
}

class CompletionResult {
  const CompletionResult({
    required this.complete,
    required this.reason,
    required this.remainingIds,
  });

  final bool complete;
  final String reason;
  final List<String> remainingIds;

  static CompletionResult parse(String text) {
    final decoded = _decodeJsonObject(text);

    final rawComplete = decoded['complete'];
    final complete = switch (rawComplete) {
      bool value => value,
      String value => value.toLowerCase() == 'true',
      _ => throw FormatException('Invalid complete value: $rawComplete'),
    };

    final reason = decoded['reason']?.toString() ?? '';
    final rawRemaining = decoded['remaining_ids'];
    final remainingIds = rawRemaining is List
        ? rawRemaining.map((value) => value.toString()).toList(growable: false)
        : <String>[];

    return CompletionResult(
      complete: complete,
      reason: reason,
      remainingIds: remainingIds,
    );
  }

  static Map<String, Object?> _decodeJsonObject(String text) {
    Object? decode(String candidate) => jsonDecode(candidate);

    try {
      final value = decode(text.trim());
      if (value is Map<String, Object?>) {
        return value;
      }
    } catch (_) {
      // Fall through to tolerant extraction below.
    }

    final fenced = RegExp(
      r'```json\s*(\{[\s\S]*?\})\s*```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fenced != null) {
      final value = decode(fenced.group(1)!);
      if (value is Map<String, Object?>) {
        return value;
      }
    }

    final object = RegExp(r'(\{[\s\S]*\})').firstMatch(text);
    if (object != null) {
      final value = decode(object.group(1)!);
      if (value is Map<String, Object?>) {
        return value;
      }
    }

    throw const FormatException('Could not parse completion JSON.');
  }
}

class Options {
  const Options({
    required this.planPath,
    required this.repoRoot,
    required this.codexCommand,
    required this.model,
    required this.advanceSandbox,
    required this.maxIterations,
    required this.delaySeconds,
    required this.failureLimit,
    required this.summaryLines,
    required this.advanceTimeoutMinutes,
    required this.checkTimeoutMinutes,
    required this.validationCommands,
    required this.validationTimeoutMinutes,
    required this.repairAttempts,
    required this.logDir,
    required this.dangerous,
    required this.showCodexOutput,
    required this.showCodexActivity,
    required this.showCodexTail,
    required this.activityLines,
    required this.tailIntervalMs,
    required this.dryRun,
    required this.help,
  });

  final String planPath;
  final Directory repoRoot;
  final String codexCommand;
  final String model;
  final String advanceSandbox;
  final int maxIterations;
  final int delaySeconds;
  final int failureLimit;
  final int summaryLines;
  final int advanceTimeoutMinutes;
  final int checkTimeoutMinutes;
  final List<String> validationCommands;
  final int validationTimeoutMinutes;
  final int repairAttempts;
  final Directory logDir;
  final bool dangerous;
  final bool showCodexOutput;
  final bool showCodexActivity;
  final bool showCodexTail;
  final int activityLines;
  final int tailIntervalMs;
  final bool dryRun;
  final bool help;

  static Options parse(List<String> args) {
    final values = <String, String>{};
    final listValues = <String, List<String>>{};
    final flags = <String>{};

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '-h' || arg == '--help') {
        flags.add('help');
        continue;
      }

      if (!arg.startsWith('--')) {
        fail('Unknown argument: $arg');
      }

      final withoutPrefix = arg.substring(2);
      final equalsIndex = withoutPrefix.indexOf('=');

      if (equalsIndex >= 0) {
        final key = withoutPrefix.substring(0, equalsIndex);
        final value = withoutPrefix.substring(equalsIndex + 1);
        if (key == 'validation-command') {
          listValues.putIfAbsent(key, () => <String>[]).add(value);
        } else {
          values[key] = value;
        }
        continue;
      }

      const booleanFlags = {
        'dangerous',
        'show-codex-output',
        'no-codex-activity',
        'no-codex-tail',
        'skip-host-validation',
        'dry-run',
      };

      if (booleanFlags.contains(withoutPrefix)) {
        flags.add(withoutPrefix);
        continue;
      }

      if (i + 1 >= args.length) {
        fail('Missing value for --$withoutPrefix');
      }
      final value = args[++i];
      if (withoutPrefix == 'validation-command') {
        listValues.putIfAbsent(withoutPrefix, () => <String>[]).add(value);
      } else {
        values[withoutPrefix] = value;
      }
    }

    final repoRoot = Directory(values['repo'] ?? Directory.current.path);
    final logDir = Directory(
      values['log-dir'] ??
          joinPath(Directory.systemTemp.path, 'codex-advanced-plan-runs'),
    );
    final advanceSandbox = values['advance-sandbox'] ?? 'danger-full-access';
    const allowedSandboxes = {
      'read-only',
      'workspace-write',
      'danger-full-access',
    };
    if (!allowedSandboxes.contains(advanceSandbox)) {
      fail('Invalid --advance-sandbox: $advanceSandbox');
    }
    final validationCommands = flags.contains('skip-host-validation')
        ? <String>[]
        : (listValues['validation-command'] == null ||
                listValues['validation-command']!.isEmpty)
            ? <String>['flutter analyze']
            : List<String>.unmodifiable(listValues['validation-command']!);

    return Options(
      planPath: values['plan'] ?? _defaultPlanPath,
      repoRoot: repoRoot,
      codexCommand: values['codex'] ?? 'codex',
      model: values['model'] ?? '',
      advanceSandbox: advanceSandbox,
      maxIterations: parseInt(values['max-iterations'], fallback: 0),
      delaySeconds: parseInt(values['delay-seconds'], fallback: 0),
      failureLimit: parseInt(values['failure-limit'], fallback: 3),
      summaryLines: parseInt(values['summary-lines'], fallback: 3).clamp(1, 8),
      advanceTimeoutMinutes:
          parseInt(values['advance-timeout-minutes'], fallback: 45)
              .clamp(1, 240),
      checkTimeoutMinutes:
          parseInt(values['check-timeout-minutes'], fallback: 10).clamp(1, 60),
      validationCommands: validationCommands,
      validationTimeoutMinutes:
          parseInt(values['validation-timeout-minutes'], fallback: 10)
              .clamp(1, 120),
      repairAttempts:
          parseInt(values['repair-attempts'], fallback: 2).clamp(0, 10),
      logDir: logDir,
      dangerous: flags.contains('dangerous'),
      showCodexOutput: flags.contains('show-codex-output'),
      showCodexActivity: !flags.contains('no-codex-activity'),
      showCodexTail: !flags.contains('no-codex-tail'),
      activityLines:
          parseInt(values['activity-lines'], fallback: 16).clamp(0, 80),
      tailIntervalMs:
          parseInt(values['tail-interval-ms'], fallback: 2500).clamp(0, 60000),
      dryRun: flags.contains('dry-run'),
      help: flags.contains('help'),
    );
  }

  static int parseInt(String? value, {required int fallback}) {
    if (value == null || value.isEmpty) {
      return fallback;
    }
    return int.tryParse(value) ?? fallback;
  }

  static const usage = '''
Usage:
  dart run tool/run_advanced_plan_with_codex.dart [options]

Options:
  --plan <path>             Plan file path. Default: $_defaultPlanPath
  --repo <path>             Repository root. Default: current directory
  --codex <command>         codex-cli command. Default: codex
  --model <name>            Optional model name passed to codex exec
  --advance-sandbox <mode>  Sandbox for advance/repair. Default: danger-full-access
  --max-iterations <n>      Stop after n iterations. 0 means unlimited
  --delay-seconds <n>       Delay between iterations. Default: 0
  --failure-limit <n>       Stop after n consecutive failures. Default: 3
  --summary-lines <n>       Key Codex summary lines to show. Default: 3
  --advance-timeout-minutes <n>
                            Timeout for one advance phase. Default: 45
  --check-timeout-minutes <n>
                            Timeout for one completion check phase. Default: 10
  --validation-command <cmd>
                            Host-side validation command. Repeatable.
                            Default: flutter analyze
  --validation-timeout-minutes <n>
                            Timeout for each validation command. Default: 10
  --repair-attempts <n>     Codex repair attempts after validation failure. Default: 2
  --activity-lines <n>      Filtered live Codex activity lines per phase. Default: 16
  --tail-interval-ms <n>    Minimum interval between Tail lines. Default: 2500
  --log-dir <path>          Directory for prompts and codex logs
  --dangerous               Use codex --dangerously-bypass-approvals-and-sandbox
  --show-codex-output       Mirror raw codex output to the console. Usually noisy
  --no-codex-activity       Hide filtered live Codex activity lines
  --no-codex-tail           Hide latest-message Tail lines
  --skip-host-validation    Do not run host-side validation after advance
  --dry-run                 Generate prompts and logs without invoking codex
  -h, --help                Show this help
''';
}

const completionSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['complete', 'reason', 'remaining_ids'],
  'properties': {
    'complete': {
      'type': 'boolean',
      'description': 'True only when every ADV task in the plan is finished.',
    },
    'reason': {
      'type': 'string',
      'description': 'Short human-readable explanation for the decision.',
    },
    'remaining_ids': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'ADV ids that still need work. Empty when complete is true.',
    },
  },
};
