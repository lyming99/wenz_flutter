import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  configureConsoleEncoding();
  final options = LoopOptions.parse(args);
  if (options.help) {
    stdout.write(LoopOptions.usage);
    return;
  }

  final loop = IssuePlanLoop(options);
  if (options.once) {
    await loop.runCycle();
    return;
  }

  while (true) {
    await loop.runCycle();
    await Future<void>.delayed(Duration(seconds: options.intervalSeconds));
  }
}

class IssuePlanLoop {
  IssuePlanLoop(this.options)
      : repoRoot = options.repoRoot.absolute.normalize(),
        issuesDir = options.repoRoot.absolute.normalize().childDirectory(
              options.issuesDir,
            ),
        planDir = options.repoRoot.absolute.normalize().childDirectory(
              options.planDir,
            ),
        progressDir = options.repoRoot.absolute.normalize().childDirectory(
              options.progressDir,
            );

  final LoopOptions options;
  final Directory repoRoot;
  final Directory issuesDir;
  final Directory planDir;
  final Directory progressDir;

  File get stateFile => progressDir.childFile('state.json');

  Future<void> runCycle() async {
    ensureDirectories();
    var state = ProgressState.load(stateFile);
    state = state.nextCycle();

    final issueScan = scanDirectory(
      issuesDir,
      baseDir: repoRoot,
      extensions: options.issueExtensions,
    );
    state = state.withIssueScan(issueScan);
    await state.save(stateFile);

    stdout.writeln(
      '[${clock()}] scan issues: ${issueScan.files.length} file(s), hash ${issueScan.aggregateHash.shortHash}',
    );

    final planScan = scanDirectory(
      planDir,
      baseDir: repoRoot,
      extensions: const {'.md'},
    );
    state = state.withPlanScan(planScan);
    await state.save(stateFile);

    if (issueScan.files.isEmpty) {
      await state
          .addEvent('issues.empty', 'docs/issues 没有需求文件，等待下一轮。')
          .save(stateFile);
      return;
    }

    final needsPlan = state.lastPlannedIssueHash != issueScan.aggregateHash ||
        !state.hasPlanForIssueHash(issueScan.aggregateHash);
    if (needsPlan) {
      state = await generatePlan(state, issueScan);
      await state.save(stateFile);
    }

    state = state.withPlanScan(
      scanDirectory(planDir, baseDir: repoRoot, extensions: const {'.md'}),
    );
    await state.save(stateFile);

    final nextPlan = state.nextRunnablePlan();
    if (nextPlan == null) {
      stdout.writeln('[${clock()}] all plans complete; waiting...');
      await state.addEvent('plans.idle', '所有 plan 已完成，等待新需求。').save(stateFile);
      return;
    }

    await processPlan(state, nextPlan);
  }

  void ensureDirectories() {
    issuesDir.createSync(recursive: true);
    planDir.createSync(recursive: true);
    progressDir.createSync(recursive: true);
    progressDir.childDirectory('logs').createSync(recursive: true);
  }

  Future<ProgressState> generatePlan(
    ProgressState state,
    DirectoryScan issueScan,
  ) async {
    final planPath = planDir.childFile(
      'plan_${timestampForPath()}_${issueScan.aggregateHash.shortHash}.md',
    );
    final issueBundle = buildIssueBundle(issueScan);
    final prompt = [
      '你是当前仓库的需求整理与开发计划生成者。',
      '请读取下面从 docs/issues 收集到的反馈和需求，生成一个可执行开发计划。',
      '',
      '输出文件：',
      planPath.path,
      '',
      '计划格式必须包含：',
      '- 标题',
      '- 需求来源列表',
      '- 任务列表，任务必须使用 Markdown checkbox：- [ ] P001: 任务标题',
      '- 每个任务的验收要点',
      '- 总体验收标准',
      '- 进度区',
      '',
      '约束：',
      '- 使用中文。',
      '- 只写入上述 plan 文件，不要改业务代码。',
      '- 不要输出完整 diff、源码全文或长文件列表。',
      '- Windows/PowerShell 读取中文文件时必须显式使用 UTF-8。',
      '',
      '需求快照：',
      issueBundle,
    ].join('\n');

    stdout.writeln('[${clock()}] generate plan: ${planPath.path}');
    final result = await runCodex(
      prompt: prompt,
      phase: 'generate-plan',
      outputPrefix: 'generate-plan-${issueScan.aggregateHash.shortHash}',
    );

    if (result.exitCode != 0 || !planPath.existsSync()) {
      return state
          .addEvent(
            'plan.generate.failed',
            '生成 plan 失败，exit=${result.exitCode}，log=${result.logFile.path}',
          )
          .withLastPlannedIssueHash(issueScan.aggregateHash);
    }

    final planHash = fileHash(planPath);
    return state
        .upsertPlan(
          PlanProgress(
            path: repoRelative(planPath.path),
            hash: planHash,
            issueHash: issueScan.aggregateHash,
            status: PlanStatus.pending,
            completedTasks: 0,
            totalTasks: 0,
            validationPassed: false,
            updatedAt: DateTime.now(),
          ),
        )
        .withLastPlannedIssueHash(issueScan.aggregateHash)
        .addEvent('plan.generated', repoRelative(planPath.path));
  }

  Future<void> processPlan(
      ProgressState initialState, PlanProgress plan) async {
    var state = ProgressState.load(stateFile);
    final planFile = repoRoot.childFile(plan.path);
    if (!planFile.existsSync()) {
      await state
          .updatePlanStatus(plan.path, PlanStatus.missing)
          .addEvent('plan.missing', plan.path)
          .save(stateFile);
      return;
    }

    var parsed = parsePlan(planFile);
    state = state.upsertPlan(
      plan.copyWith(
        hash: fileHash(planFile),
        status: parsed.isComplete
            ? PlanStatus.readyForValidation
            : PlanStatus.running,
        completedTasks: parsed.completedCount,
        totalTasks: parsed.tasks.length,
        updatedAt: DateTime.now(),
      ),
    );
    await state.save(stateFile);

    if (!parsed.isComplete) {
      final task = parsed.nextTask!;
      await executeTask(planFile, task);
      parsed = parsePlan(planFile);
      state = ProgressState.load(stateFile).upsertPlan(
        plan.copyWith(
          hash: fileHash(planFile),
          status: parsed.isComplete
              ? PlanStatus.readyForValidation
              : PlanStatus.running,
          completedTasks: parsed.completedCount,
          totalTasks: parsed.tasks.length,
          updatedAt: DateTime.now(),
        ),
      );
      await state
          .addEvent('task.executed', '${plan.path} :: ${task.title}')
          .save(
            stateFile,
          );
      if (!parsed.isComplete) {
        return;
      }
    }

    await validatePlan(planFile, plan.path);
  }

  Future<void> executeTask(File planFile, PlanTask task) async {
    stdout.writeln('[${clock()}] execute task: ${task.title}');
    final prompt = [
      '你是当前仓库的开发执行者。',
      '请根据 plan 文件只执行下一个未完成任务。',
      '',
      'plan 文件：',
      planFile.path,
      '',
      '本轮任务：',
      task.rawLine,
      '',
      '执行要求：',
      '- 只处理这个任务，不要提前执行后续 checkbox 任务。',
      '- 完成后把对应 checkbox 从 [ ] 改成 [x]，并更新 plan 的进度区。',
      '- 需要补代码、测试、文档时按仓库现有风格最小改动。',
      '- 可以运行必要验证；Flutter/analyze 命令请给足超时时间。',
      '- 不要输出完整 diff、源码全文或长文件列表。',
      '- Windows/PowerShell 读取中文文件时必须显式使用 UTF-8。',
      '',
      '最终回复用中文简短说明：完成内容、验证情况、是否阻塞。',
    ].join('\n');

    await runCodex(
      prompt: prompt,
      phase: 'execute-task',
      outputPrefix: 'execute-${safeFilePart(task.id)}',
    );
  }

  Future<void> validatePlan(File planFile, String planPath) async {
    var state = ProgressState.load(stateFile);
    stdout.writeln('[${clock()}] validate plan: $planPath');

    var validation =
        await runValidation('validation-${safeFilePart(planPath)}');
    for (var attempt = 1;
        !validation.success && attempt <= options.repairAttempts;
        attempt++) {
      await state
          .updatePlanStatus(planPath, PlanStatus.validationFailed)
          .addEvent(
            'validation.failed',
            '$planPath :: ${validation.failedCommand} :: ${validation.logFile.path}',
          )
          .save(stateFile);

      await repairValidation(planFile, validation, attempt);
      validation = await runValidation(
        'validation-${safeFilePart(planPath)}-repair-$attempt',
      );
    }

    state = ProgressState.load(stateFile);
    if (validation.success) {
      await state
          .updatePlanStatus(planPath, PlanStatus.completed,
              validationPassed: true)
          .addEvent('plan.completed', planPath)
          .save(stateFile);
      stdout.writeln('[${clock()}] validate passed: $planPath');
    } else {
      await state
          .updatePlanStatus(planPath, PlanStatus.validationFailed)
          .addEvent(
            'validation.failed.final',
            '$planPath :: ${validation.logFile.path}',
          )
          .save(stateFile);
      stdout
          .writeln('[${clock()}] validate failed: ${validation.logFile.path}');
    }
  }

  Future<void> repairValidation(
    File planFile,
    ValidationResult validation,
    int attempt,
  ) async {
    stdout.writeln('[${clock()}] repair validation: attempt $attempt');
    final prompt = [
      '你是当前仓库的验证错误修复者。',
      'plan 已完成 checkbox 任务，但宿主机 analyze/test 验收失败。请只修复验证错误。',
      '',
      'plan 文件：',
      planFile.path,
      '',
      '失败命令：',
      validation.failedCommand ?? 'unknown',
      '',
      '失败输出摘要：',
      validation.outputForPrompt(maxChars: 12000),
      '',
      '要求：',
      '- 只修复验证错误，不要新增需求或推进其它 plan。',
      '- 修复后可更新 plan 进度区，但不要把失败验收伪装成通过。',
      '- 不要输出完整 diff、源码全文或长文件列表。',
      '- 中文文件读写必须使用 UTF-8。',
    ].join('\n');

    await runCodex(
      prompt: prompt,
      phase: 'repair-validation',
      outputPrefix: 'repair-validation-$attempt',
    );
  }

  Future<ValidationResult> runValidation(String label) async {
    if (options.validationCommands.isEmpty) {
      return ValidationResult.success(
        logFile: progressDir.childFile('logs/$label-skipped.log'),
      );
    }

    final logFile = progressDir.childFile('logs/$label.log');
    final sink = logFile.openWrite(encoding: utf8);
    try {
      for (final command in options.validationCommands) {
        stdout.writeln('[${clock()}] analyze: $command');
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
          return ValidationResult.failure(
            logFile: logFile,
            failedCommand: command,
            output: result.output,
          );
        }
      }
      return ValidationResult.success(logFile: logFile);
    } finally {
      await sink.close();
    }
  }

  Future<CodexRunResult> runCodex({
    required String prompt,
    required String phase,
    required String outputPrefix,
  }) async {
    final stamp = timestampForPath();
    final logFile = progressDir.childFile('logs/${stamp}_$outputPrefix.log');
    final lastMessageFile =
        progressDir.childFile('logs/${stamp}_$outputPrefix.last.txt');
    final promptFile = progressDir
        .childFile('logs/${stamp}_$outputPrefix.prompt.txt')
      ..writeAsStringSync(prompt, encoding: utf8);

    final args = <String>[
      'exec',
      '--cd',
      repoRoot.path,
      '--color',
      'never',
      '-o',
      lastMessageFile.path,
      if (options.model.isNotEmpty) ...['-m', options.model],
      if (options.dangerous)
        '--dangerously-bypass-approvals-and-sandbox'
      else ...[
        '--sandbox',
        options.advanceSandbox,
      ],
      '-',
    ];

    stdout.writeln('[${clock()}] codex $phase');
    final process = await Process.start(
      options.codexCommand,
      args,
      workingDirectory: repoRoot.path,
      runInShell: Platform.isWindows,
    );
    process.stdin.encoding = utf8;
    process.stdin.write(prompt);
    await process.stdin.close();

    final sink = logFile.openWrite(encoding: utf8);
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(sink.write)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(sink.write)
        .asFuture<void>();

    var timedOut = false;
    final exitCode = await process.exitCode.timeout(
      Duration(minutes: options.codexTimeoutMinutes),
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
      stdout.writeln('[${clock()}] codex $phase timeout: ${logFile.path}');
    } else if (exitCode != 0) {
      stdout.writeln('[${clock()}] codex $phase failed: ${logFile.path}');
    }

    return CodexRunResult(
      exitCode: timedOut ? -1 : exitCode,
      logFile: logFile,
      lastMessageFile: lastMessageFile,
      promptFile: promptFile,
    );
  }

  String buildIssueBundle(DirectoryScan issueScan) {
    final buffer = StringBuffer();
    for (final file in issueScan.files) {
      final source = repoRoot.childFile(file.path);
      buffer
        ..writeln('---')
        ..writeln('path: ${file.path}')
        ..writeln('hash: ${file.hash}')
        ..writeln('modifiedAt: ${file.modifiedAt}')
        ..writeln('content:')
        ..writeln(readTextSnippet(source, maxChars: options.issueMaxChars));
    }
    return buffer.toString();
  }

  String repoRelative(String path) {
    final absolute = File(path).absolute.normalize().path;
    final root = repoRoot.path;
    if (absolute.toLowerCase().startsWith(root.toLowerCase())) {
      var relative = absolute.substring(root.length);
      while (relative.startsWith(Platform.pathSeparator)) {
        relative = relative.substring(1);
      }
      return relative.replaceAll('\\', '/');
    }
    return path.replaceAll('\\', '/');
  }
}

class LoopOptions {
  const LoopOptions({
    required this.repoRoot,
    required this.issuesDir,
    required this.planDir,
    required this.progressDir,
    required this.intervalSeconds,
    required this.once,
    required this.codexCommand,
    required this.model,
    required this.advanceSandbox,
    required this.dangerous,
    required this.codexTimeoutMinutes,
    required this.validationCommands,
    required this.validationTimeoutMinutes,
    required this.repairAttempts,
    required this.issueExtensions,
    required this.issueMaxChars,
    required this.help,
  });

  final Directory repoRoot;
  final String issuesDir;
  final String planDir;
  final String progressDir;
  final int intervalSeconds;
  final bool once;
  final String codexCommand;
  final String model;
  final String advanceSandbox;
  final bool dangerous;
  final int codexTimeoutMinutes;
  final List<String> validationCommands;
  final int validationTimeoutMinutes;
  final int repairAttempts;
  final Set<String> issueExtensions;
  final int issueMaxChars;
  final bool help;

  static LoopOptions parse(List<String> args) {
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
      final keyValue = arg.substring(2);
      final equals = keyValue.indexOf('=');
      if (equals >= 0) {
        final key = keyValue.substring(0, equals);
        final value = keyValue.substring(equals + 1);
        if (key == 'validation-command') {
          listValues.putIfAbsent(key, () => <String>[]).add(value);
        } else {
          values[key] = value;
        }
        continue;
      }
      const bools = {'once', 'dangerous', 'skip-validation'};
      if (bools.contains(keyValue)) {
        flags.add(keyValue);
        continue;
      }
      if (i + 1 >= args.length) {
        fail('Missing value for --$keyValue');
      }
      final value = args[++i];
      if (keyValue == 'validation-command') {
        listValues.putIfAbsent(keyValue, () => <String>[]).add(value);
      } else {
        values[keyValue] = value;
      }
    }

    final validationCommands = flags.contains('skip-validation')
        ? <String>[]
        : (listValues['validation-command'] == null ||
                listValues['validation-command']!.isEmpty)
            ? <String>['flutter analyze']
            : List<String>.unmodifiable(listValues['validation-command']!);

    return LoopOptions(
      repoRoot: Directory(values['repo'] ?? Directory.current.path),
      issuesDir: values['issues-dir'] ?? 'docs/issues',
      planDir: values['plan-dir'] ?? 'docs/plan',
      progressDir: values['progress-dir'] ?? 'docs/progress',
      intervalSeconds: parseInt(values['interval-seconds'], 5).clamp(1, 3600),
      once: flags.contains('once'),
      codexCommand: values['codex'] ?? 'codex',
      model: values['model'] ?? '',
      advanceSandbox: values['advance-sandbox'] ?? 'danger-full-access',
      dangerous: flags.contains('dangerous'),
      codexTimeoutMinutes: parseInt(values['codex-timeout-minutes'], 45).clamp(
        1,
        240,
      ),
      validationCommands: validationCommands,
      validationTimeoutMinutes:
          parseInt(values['validation-timeout-minutes'], 10).clamp(1, 120),
      repairAttempts: parseInt(values['repair-attempts'], 2).clamp(0, 10),
      issueExtensions: parseExtensions(values['issue-extensions']),
      issueMaxChars: parseInt(values['issue-max-chars'], 20000).clamp(
        1000,
        200000,
      ),
      help: flags.contains('help'),
    );
  }

  static int parseInt(String? value, int fallback) {
    if (value == null) {
      return fallback;
    }
    return int.tryParse(value) ?? fallback;
  }

  static Set<String> parseExtensions(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const {'.md', '.txt', '.json', '.yaml', '.yml'};
    }
    return value
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .map((item) => item.startsWith('.') ? item : '.$item')
        .toSet();
  }

  static const usage = '''
Usage:
  dart run tool/issues_plan_loop.dart [options]

Loop:
  --interval-seconds <n>       Loop interval. Default: 5
  --once                       Run one cycle then exit

Directories:
  --issues-dir <path>          Default: docs/issues
  --plan-dir <path>            Default: docs/plan
  --progress-dir <path>        Default: docs/progress

Codex:
  --codex <command>            Default: codex
  --model <name>               Optional model
  --advance-sandbox <mode>     Default: danger-full-access
  --dangerous                  Use bypass approvals and sandbox
  --codex-timeout-minutes <n>  Default: 45

Validation:
  --validation-command <cmd>   Repeatable. Default: flutter analyze
  --validation-timeout-minutes <n>
                               Default: 10
  --repair-attempts <n>        Default: 2
  --skip-validation            Disable host-side validation

Issues:
  --issue-extensions <csv>     Default: .md,.txt,.json,.yaml,.yml
  --issue-max-chars <n>        Max chars per issue file in prompt
''';
}

class ProgressState {
  const ProgressState({
    required this.version,
    required this.cycle,
    required this.updatedAt,
    required this.lastPlannedIssueHash,
    required this.issueScan,
    required this.planScan,
    required this.plans,
    required this.events,
  });

  factory ProgressState.initial() {
    return ProgressState(
      version: 1,
      cycle: 0,
      updatedAt: DateTime.now(),
      lastPlannedIssueHash: null,
      issueScan: DirectoryScan.empty(),
      planScan: DirectoryScan.empty(),
      plans: const {},
      events: const [],
    );
  }

  final int version;
  final int cycle;
  final DateTime updatedAt;
  final String? lastPlannedIssueHash;
  final DirectoryScan issueScan;
  final DirectoryScan planScan;
  final Map<String, PlanProgress> plans;
  final List<ProgressEvent> events;

  static ProgressState load(File file) {
    for (final candidate in [
      file,
      File('${file.path}.mirror'),
      File('${file.path}.bak'),
    ]) {
      if (!candidate.existsSync()) {
        continue;
      }
      try {
        final decoded = jsonDecode(candidate.readAsStringSync(encoding: utf8));
        if (decoded is Map<String, Object?>) {
          return ProgressState.fromJson(decoded);
        }
      } catch (_) {
        continue;
      }
    }
    return ProgressState.initial();
  }

  ProgressState nextCycle() {
    return copyWith(cycle: cycle + 1, updatedAt: DateTime.now());
  }

  ProgressState withIssueScan(DirectoryScan scan) {
    return copyWith(issueScan: scan, updatedAt: DateTime.now());
  }

  ProgressState withPlanScan(DirectoryScan scan) {
    return copyWith(planScan: scan, updatedAt: DateTime.now());
  }

  ProgressState withLastPlannedIssueHash(String hash) {
    return copyWith(lastPlannedIssueHash: hash, updatedAt: DateTime.now());
  }

  bool hasPlanForIssueHash(String issueHash) {
    return plans.values.any((plan) => plan.issueHash == issueHash);
  }

  PlanProgress? nextRunnablePlan() {
    final candidates = plans.values
        .where((plan) => plan.status != PlanStatus.completed)
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return candidates.isEmpty ? null : candidates.first;
  }

  ProgressState upsertPlan(PlanProgress plan) {
    final next = Map<String, PlanProgress>.from(plans);
    next[plan.path] = plan;
    return copyWith(plans: next, updatedAt: DateTime.now());
  }

  ProgressState updatePlanStatus(
    String path,
    PlanStatus status, {
    bool? validationPassed,
  }) {
    final current = plans[path];
    if (current == null) {
      return this;
    }
    return upsertPlan(
      current.copyWith(
        status: status,
        validationPassed: validationPassed ?? current.validationPassed,
        updatedAt: DateTime.now(),
      ),
    );
  }

  ProgressState addEvent(String type, String message) {
    final next = [
      ...events,
      ProgressEvent(type: type, message: message, at: DateTime.now()),
    ];
    final capped = next.length > 200 ? next.sublist(next.length - 200) : next;
    return copyWith(events: capped, updatedAt: DateTime.now());
  }

  Future<void> save(File file) async {
    await writeJsonDouble(file, toJson());
  }

  ProgressState copyWith({
    int? cycle,
    DateTime? updatedAt,
    String? lastPlannedIssueHash,
    DirectoryScan? issueScan,
    DirectoryScan? planScan,
    Map<String, PlanProgress>? plans,
    List<ProgressEvent>? events,
  }) {
    return ProgressState(
      version: version,
      cycle: cycle ?? this.cycle,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPlannedIssueHash: lastPlannedIssueHash ?? this.lastPlannedIssueHash,
      issueScan: issueScan ?? this.issueScan,
      planScan: planScan ?? this.planScan,
      plans: plans ?? this.plans,
      events: events ?? this.events,
    );
  }

  factory ProgressState.fromJson(Map<String, Object?> json) {
    final plansJson = json['plans'];
    return ProgressState(
      version: json['version'] as int? ?? 1,
      cycle: json['cycle'] as int? ?? 0,
      updatedAt: parseDate(json['updatedAt']),
      lastPlannedIssueHash: json['lastPlannedIssueHash'] as String?,
      issueScan: DirectoryScan.fromJson(json['issueScan']),
      planScan: DirectoryScan.fromJson(json['planScan']),
      plans: plansJson is Map
          ? plansJson.map(
              (key, value) => MapEntry(
                key.toString(),
                PlanProgress.fromJson(value),
              ),
            )
          : const {},
      events: (json['events'] as List? ?? const [])
          .map(ProgressEvent.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'cycle': cycle,
      'updatedAt': updatedAt.toIso8601String(),
      'lastPlannedIssueHash': lastPlannedIssueHash,
      'issueScan': issueScan.toJson(),
      'planScan': planScan.toJson(),
      'plans': plans.map((key, value) => MapEntry(key, value.toJson())),
      'events': events.map((event) => event.toJson()).toList(),
    };
  }
}

class PlanProgress {
  const PlanProgress({
    required this.path,
    required this.hash,
    required this.issueHash,
    required this.status,
    required this.completedTasks,
    required this.totalTasks,
    required this.validationPassed,
    required this.updatedAt,
  });

  final String path;
  final String hash;
  final String issueHash;
  final PlanStatus status;
  final int completedTasks;
  final int totalTasks;
  final bool validationPassed;
  final DateTime updatedAt;

  PlanProgress copyWith({
    String? hash,
    PlanStatus? status,
    int? completedTasks,
    int? totalTasks,
    bool? validationPassed,
    DateTime? updatedAt,
  }) {
    return PlanProgress(
      path: path,
      hash: hash ?? this.hash,
      issueHash: issueHash,
      status: status ?? this.status,
      completedTasks: completedTasks ?? this.completedTasks,
      totalTasks: totalTasks ?? this.totalTasks,
      validationPassed: validationPassed ?? this.validationPassed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PlanProgress.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    return PlanProgress(
      path: json['path']?.toString() ?? '',
      hash: json['hash']?.toString() ?? '',
      issueHash: json['issueHash']?.toString() ?? '',
      status: PlanStatusX.parse(json['status']?.toString()),
      completedTasks: json['completedTasks'] as int? ?? 0,
      totalTasks: json['totalTasks'] as int? ?? 0,
      validationPassed: json['validationPassed'] as bool? ?? false,
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'path': path,
      'hash': hash,
      'issueHash': issueHash,
      'status': status.name,
      'completedTasks': completedTasks,
      'totalTasks': totalTasks,
      'validationPassed': validationPassed,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

enum PlanStatus {
  pending,
  running,
  readyForValidation,
  validationFailed,
  completed,
  missing,
}

extension PlanStatusX on PlanStatus {
  static PlanStatus parse(String? value) {
    return PlanStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PlanStatus.pending,
    );
  }
}

class ProgressEvent {
  const ProgressEvent({
    required this.type,
    required this.message,
    required this.at,
  });

  final String type;
  final String message;
  final DateTime at;

  factory ProgressEvent.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    return ProgressEvent(
      type: json['type']?.toString() ?? 'unknown',
      message: json['message']?.toString() ?? '',
      at: parseDate(json['at']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'type': type,
      'message': message,
      'at': at.toIso8601String(),
    };
  }
}

class DirectoryScan {
  const DirectoryScan({
    required this.root,
    required this.aggregateHash,
    required this.files,
    required this.scannedAt,
  });

  factory DirectoryScan.empty() {
    return DirectoryScan(
      root: '',
      aggregateHash: '0',
      files: const [],
      scannedAt: DateTime.now(),
    );
  }

  final String root;
  final String aggregateHash;
  final List<ScannedFile> files;
  final DateTime scannedAt;

  factory DirectoryScan.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    return DirectoryScan(
      root: json['root']?.toString() ?? '',
      aggregateHash: json['aggregateHash']?.toString() ?? '0',
      files: (json['files'] as List? ?? const [])
          .map(ScannedFile.fromJson)
          .toList(growable: false),
      scannedAt: parseDate(json['scannedAt']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'root': root,
      'aggregateHash': aggregateHash,
      'scannedAt': scannedAt.toIso8601String(),
      'files': files.map((file) => file.toJson()).toList(),
    };
  }
}

class ScannedFile {
  const ScannedFile({
    required this.path,
    required this.hash,
    required this.size,
    required this.modifiedAt,
  });

  final String path;
  final String hash;
  final int size;
  final DateTime modifiedAt;

  factory ScannedFile.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    return ScannedFile(
      path: json['path']?.toString() ?? '',
      hash: json['hash']?.toString() ?? '',
      size: json['size'] as int? ?? 0,
      modifiedAt: parseDate(json['modifiedAt']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'path': path,
      'hash': hash,
      'size': size,
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }
}

class ParsedPlan {
  const ParsedPlan(this.tasks);

  final List<PlanTask> tasks;

  bool get isComplete => tasks.isNotEmpty && tasks.every((task) => task.done);
  int get completedCount => tasks.where((task) => task.done).length;
  PlanTask? get nextTask {
    for (final task in tasks) {
      if (!task.done) {
        return task;
      }
    }
    return null;
  }
}

class PlanTask {
  const PlanTask({
    required this.id,
    required this.title,
    required this.done,
    required this.rawLine,
  });

  final String id;
  final String title;
  final bool done;
  final String rawLine;
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
    final text = output.trim();
    if (text.length <= maxChars) {
      return text;
    }
    return text.substring(text.length - maxChars);
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

class CodexRunResult {
  const CodexRunResult({
    required this.exitCode,
    required this.logFile,
    required this.lastMessageFile,
    required this.promptFile,
  });

  final int exitCode;
  final File logFile;
  final File lastMessageFile;
  final File promptFile;
}

DirectoryScan scanDirectory(
  Directory root, {
  required Directory baseDir,
  required Set<String> extensions,
}) {
  if (!root.existsSync()) {
    return DirectoryScan(
      root: root.path,
      aggregateHash: '0',
      files: const [],
      scannedAt: DateTime.now(),
    );
  }

  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => extensions.contains(extensionOf(file.path)))
      .map((file) {
    final stat = file.statSync();
    return ScannedFile(
      path: relativePath(baseDir, file),
      hash: fileHash(file),
      size: stat.size,
      modifiedAt: stat.modified,
    );
  }).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final aggregate = fnv1a64(utf8.encode(
    files.map((file) => '${file.path}|${file.hash}|${file.size}').join('\n'),
  ));
  return DirectoryScan(
    root: root.path,
    aggregateHash: aggregate,
    files: files,
    scannedAt: DateTime.now(),
  );
}

ParsedPlan parsePlan(File file) {
  final text = readText(file);
  final tasks = <PlanTask>[];
  final regex = RegExp(r'^\s*[-*]\s+\[([ xX])\]\s+(.+)$', multiLine: true);
  var index = 0;
  for (final match in regex.allMatches(text)) {
    index++;
    final title = match.group(2)!.trim();
    final idMatch =
        RegExp(r'^([A-Za-z]+[-_]?\d+|P\d+)[:：\s-]+(.+)$').firstMatch(title);
    tasks.add(
      PlanTask(
        id: idMatch?.group(1) ?? 'P${index.toString().padLeft(3, '0')}',
        title: idMatch?.group(2)?.trim() ?? title,
        done: match.group(1)!.toLowerCase() == 'x',
        rawLine: match.group(0)!,
      ),
    );
  }
  return ParsedPlan(tasks);
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
    output.writeln('Command timed out after ${timeout.inMinutes} minute(s).');
  }
  return ShellCommandResult(exitCode: code, output: output.toString());
}

Future<void> writeJsonDouble(File file, Object? data) async {
  file.parent.createSync(recursive: true);
  final encoded = const JsonEncoder.withIndent('  ').convert(data);
  final tmp = File('${file.path}.tmp');
  final mirror = File('${file.path}.mirror');
  final bak = File('${file.path}.bak');

  await tmp.writeAsString(encoded, encoding: utf8, flush: true);
  jsonDecode(await tmp.readAsString(encoding: utf8));
  await mirror.writeAsString(encoded, encoding: utf8, flush: true);
  jsonDecode(await mirror.readAsString(encoding: utf8));
  if (file.existsSync()) {
    await file.copy(bak.path);
  }
  if (file.existsSync()) {
    await file.delete();
  }
  await tmp.rename(file.path);
}

String readText(File file) {
  return const Utf8Decoder(allowMalformed: true)
      .convert(file.readAsBytesSync());
}

String readTextSnippet(File file, {required int maxChars}) {
  final text = readText(file);
  if (text.length <= maxChars) {
    return text;
  }
  return '${text.substring(0, maxChars)}\n...[truncated ${text.length - maxChars} chars]';
}

String fileHash(File file) => fnv1a64(file.readAsBytesSync());

String fnv1a64(List<int> bytes) {
  var hash = BigInt.parse('14695981039346656037');
  final prime = BigInt.parse('1099511628211');
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final byte in bytes) {
    hash = (hash ^ BigInt.from(byte)) & mask;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String extensionOf(String path) {
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  final dot = path.lastIndexOf('.');
  if (dot <= slash) {
    return '';
  }
  return path.substring(dot).toLowerCase();
}

String relativePath(Directory base, File file) {
  final basePath = base.absolute.normalize().path;
  final filePath = file.absolute.normalize().path;
  if (filePath.toLowerCase().startsWith(basePath.toLowerCase())) {
    var relative = filePath.substring(basePath.length);
    while (relative.startsWith(Platform.pathSeparator)) {
      relative = relative.substring(1);
    }
    return relative.replaceAll('\\', '/');
  }
  return filePath.replaceAll('\\', '/');
}

String safeFilePart(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
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
  return '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
}

DateTime parseDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

void configureConsoleEncoding() {
  try {
    stdout.encoding = utf8;
    stderr.encoding = utf8;
  } catch (_) {}
}

void fail(String message) {
  stderr.writeln(message);
  exit(1);
}

extension DirectoryPaths on Directory {
  Directory normalize() => Directory(File(path).absolute.normalize().path);

  Directory childDirectory(String path) {
    return Directory(joinPath(this.path, path));
  }

  File childFile(String path) {
    return File(joinPath(this.path, path));
  }
}

extension FilePaths on File {
  File normalize() => File(Uri.file(path).normalizePath().toFilePath());
}

extension ShortHash on String {
  String get shortHash => length <= 8 ? this : substring(0, 8);
}

String joinPath(String left, String right) {
  if (right.contains('/') || right.contains('\\')) {
    final parts = right.split(RegExp(r'[/\\]+'));
    return parts.fold(left, joinPath);
  }
  if (left.isEmpty) {
    return right;
  }
  return left.endsWith(Platform.pathSeparator)
      ? '$left$right'
      : '$left${Platform.pathSeparator}$right';
}
