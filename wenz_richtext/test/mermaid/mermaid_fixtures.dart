import 'package:wenz_richtext/wenz_richtext.dart';

class MermaidFixture {
  const MermaidFixture({
    required this.name,
    required this.type,
    required this.minimum,
    required this.cjk,
    required this.longText,
    required this.invalid,
  });

  final String name;
  final DiagramType type;
  final String minimum;
  final String cjk;
  final String longText;
  final String invalid;
}

const List<MermaidFixture> supportedMermaidFixtures = <MermaidFixture>[
  MermaidFixture(
    name: 'flowchart',
    type: DiagramType.flowchart,
    minimum: 'flowchart TD\n  A --> B',
    cjk: 'flowchart LR\n  A[开始 🚀] -->|通过| B{审批}\n  B --> C[完成]',
    longText: 'flowchart TD\n  A[这是一个用于验证长中文标签换行与布局稳定性的流程节点] --> B[结束]',
    invalid: 'flowchart',
  ),
  MermaidFixture(
    name: 'sequence',
    type: DiagramType.sequence,
    minimum: 'sequenceDiagram\n  A->>B: Hello',
    cjk:
        'sequenceDiagram\n  participant U as 用户 👋\n  participant S as 服务端\n  U->>S: 创建订单\n  S-->>U: 已确认',
    longText:
        'sequenceDiagram\n  participant A as 客户端\n  participant B as 服务端\n  A->>B: 发送一条很长的中文请求消息以验证文本布局',
    invalid: 'sequence',
  ),
  MermaidFixture(
    name: 'pie',
    type: DiagramType.pieChart,
    minimum: 'pie\n  "A" : 1\n  "B" : 2',
    cjk: 'pie showData\n  title 宠物占比 🐱\n  "猫" : 60\n  "狗" : 40',
    longText:
        'pie showData\n  title 很长的中文饼图标题\n  "需要在图例中完整显示的长中文分类" : 70\n  "其他" : 30',
    invalid: 'not a pie chart',
  ),
  MermaidFixture(
    name: 'gantt',
    type: DiagramType.ganttChart,
    minimum:
        'gantt\n  dateFormat YYYY-MM-DD\n  section Work\n    Task :a, 2026-01-01, 1d',
    cjk:
        'gantt\n  title 发布计划 🚀\n  dateFormat YYYY-MM-DD\n  section 开发\n    实现核心 :done, core, 2026-07-01, 2d\n    验证路径 :after core, 3d',
    longText:
        'gantt\n  dateFormat YYYY-MM-DD\n  section 交付\n    这是一个用于验证甘特图长中文任务名称的任务 :a, 2026-01-01, 5d',
    invalid: 'gantt diagram',
  ),
  MermaidFixture(
    name: 'timeline',
    type: DiagramType.timeline,
    minimum: 'timeline\n  2024 : Alpha',
    cjk: 'timeline\n  title 产品里程碑 🚀\n  2024 : 立项\n  2025 : 发布',
    longText: 'timeline\n  title 很长的产品演进时间线\n  2026 : 这是一个用于验证时间线长中文事件文本的里程碑',
    invalid: 'time line',
  ),
  MermaidFixture(
    name: 'kanban',
    type: DiagramType.kanban,
    minimum: 'kanban\n  todo[Todo]\n    task1[Write parser]',
    cjk:
        'kanban\n  title 发布看板 🚀\n  todo[待办]\n    task1[编写解析器]\n  done[完成]\n    task2[发布预览]',
    longText: 'kanban\n  todo[待办]\n    task1[这是一个用于验证看板卡片长中文文本布局的任务]',
    invalid: 'kan ban',
  ),
  MermaidFixture(
    name: 'mindmap',
    type: DiagramType.mindmap,
    minimum: 'mindmap\n  root((Root))\n    child[Child]',
    cjk: 'mindmap\n  root((产品 🚀))\n    plan[计划]\n      ship(发布)',
    longText: 'mindmap\n  root((中心主题))\n    branch[这是一个用于验证思维导图长中文节点自动测量的分支]',
    invalid: 'mind map',
  ),
  MermaidFixture(
    name: 'radar',
    type: DiagramType.radar,
    minimum: 'radar-beta\naxis A, B, C\ncurve Team{1,2,3}',
    cjk:
        'radar-beta\ntitle 技能雷达 🚀\naxis 编码["编码"], 设计["设计"], 测试["测试"]\ncurve 团队["团队"]{80,70,90}',
    longText:
        'radar-beta\ntitle 很长的能力评估标题\naxis architecture["架构设计能力"], delivery["持续交付能力"], quality["质量保障能力"]\ncurve team["研发团队"]{80,70,90}',
    invalid: 'radar',
  ),
  MermaidFixture(
    name: 'xy chart',
    type: DiagramType.xyChart,
    minimum: 'xychart-beta\nx-axis [A, B]\ny-axis 0 --> 10\nbar [2, 4]',
    cjk:
        'xychart-beta\ntitle "季度收入 🚀"\nx-axis "季度" [一, 二, 三]\ny-axis "金额" 0 --> 100\nbar [20, 40, 60]\nline [30, 50, 70]',
    longText:
        'xychart-beta\ntitle "很长的中文趋势图标题"\nx-axis "时间范围" [第一季度, 第二季度, 第三季度]\ny-axis "累计金额" 0 --> 100\nline [20, 50, 90]',
    invalid: 'xy chart',
  ),
];
