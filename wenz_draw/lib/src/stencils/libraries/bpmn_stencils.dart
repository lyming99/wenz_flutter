/// BPMN 2.0 stencil library.
/// Based on draw.io BPMN shapes for business process modeling.
///
/// Covers events (start, intermediate, end), activities (tasks, sub-processes),
/// gateways (exclusive, parallel, inclusive, event, complex), data shapes,
/// swimlanes and annotation artifacts.

class BpmnStencils {
  const BpmnStencils._();

  static const Map<String, List<String>> aliases = {
    'bpmn.startEvent': <String>[
      'mxgraph.bpmn.startEvent',
      'mxgraph.bpmn.start_event',
      'mxgraph.bpmn.start-event',
      'shape=startEvent',
    ],
    'bpmn.startEvent.timer': <String>[
      'mxgraph.bpmn.startEventTimer',
      'mxgraph.bpmn.start_event_timer',
      'mxgraph.bpmn.start-event-timer',
    ],
    'bpmn.startEvent.message': <String>[
      'mxgraph.bpmn.startEventMessage',
      'mxgraph.bpmn.start_event_message',
      'mxgraph.bpmn.start-event-message',
    ],
    'bpmn.startEvent.signal': <String>[
      'mxgraph.bpmn.startEventSignal',
      'mxgraph.bpmn.start_event_signal',
      'mxgraph.bpmn.start-event-signal',
    ],
    'bpmn.intermediateEvent': <String>[
      'mxgraph.bpmn.intermediateEvent',
      'mxgraph.bpmn.intermediate_event',
      'mxgraph.bpmn.intermediate-event',
    ],
    'bpmn.intermediateEvent.message': <String>[
      'mxgraph.bpmn.intermediateEventMessage',
      'mxgraph.bpmn.intermediate_event_message',
      'mxgraph.bpmn.intermediate-event-message',
    ],
    'bpmn.intermediateEvent.signal': <String>[
      'mxgraph.bpmn.intermediateEventSignal',
      'mxgraph.bpmn.intermediate_event_signal',
      'mxgraph.bpmn.intermediate-event-signal',
    ],
    'bpmn.endEvent': <String>[
      'mxgraph.bpmn.endEvent',
      'mxgraph.bpmn.end_event',
      'mxgraph.bpmn.end-event',
    ],
    'bpmn.endEvent.message': <String>[
      'mxgraph.bpmn.endEventMessage',
      'mxgraph.bpmn.end_event_message',
      'mxgraph.bpmn.end-event-message',
    ],
    'bpmn.endEvent.terminate': <String>[
      'mxgraph.bpmn.endEventTerminate',
      'mxgraph.bpmn.end_event_terminate',
      'mxgraph.bpmn.end-event-terminate',
    ],
    'bpmn.task': <String>[
      'mxgraph.bpmn.task',
      'mxgraph.bpmn.activity',
    ],
    'bpmn.task.user': <String>[
      'mxgraph.bpmn.userTask',
      'mxgraph.bpmn.user_task',
      'mxgraph.bpmn.user-task',
    ],
    'bpmn.task.service': <String>[
      'mxgraph.bpmn.serviceTask',
      'mxgraph.bpmn.service_task',
      'mxgraph.bpmn.service-task',
    ],
    'bpmn.task.send': <String>[
      'mxgraph.bpmn.sendTask',
      'mxgraph.bpmn.send_task',
      'mxgraph.bpmn.send-task',
    ],
    'bpmn.task.receive': <String>[
      'mxgraph.bpmn.receiveTask',
      'mxgraph.bpmn.receive_task',
      'mxgraph.bpmn.receive-task',
    ],
    'bpmn.task.manual': <String>[
      'mxgraph.bpmn.manualTask',
      'mxgraph.bpmn.manual_task',
      'mxgraph.bpmn.manual-task',
    ],
    'bpmn.task.script': <String>[
      'mxgraph.bpmn.scriptTask',
      'mxgraph.bpmn.script_task',
      'mxgraph.bpmn.script-task',
    ],
    'bpmn.subProcess': <String>[
      'mxgraph.bpmn.subProcess',
      'mxgraph.bpmn.sub_process',
      'mxgraph.bpmn.sub-process',
    ],
    'bpmn.gateway.exclusive': <String>[
      'mxgraph.bpmn.exclusiveGateway',
      'mxgraph.bpmn.exclusive_gateway',
      'mxgraph.bpmn.exclusive-gateway',
    ],
    'bpmn.gateway.parallel': <String>[
      'mxgraph.bpmn.parallelGateway',
      'mxgraph.bpmn.parallel_gateway',
      'mxgraph.bpmn.parallel-gateway',
    ],
    'bpmn.gateway.inclusive': <String>[
      'mxgraph.bpmn.inclusiveGateway',
      'mxgraph.bpmn.inclusive_gateway',
      'mxgraph.bpmn.inclusive-gateway',
    ],
    'bpmn.gateway.event': <String>[
      'mxgraph.bpmn.eventGateway',
      'mxgraph.bpmn.event_gateway',
      'mxgraph.bpmn.event-gateway',
    ],
    'bpmn.gateway.complex': <String>[
      'mxgraph.bpmn.complexGateway',
      'mxgraph.bpmn.complex_gateway',
      'mxgraph.bpmn.complex-gateway',
    ],
    'bpmn.dataObject': <String>[
      'mxgraph.bpmn.dataObject',
      'mxgraph.bpmn.data_object',
      'mxgraph.bpmn.data-object',
    ],
    'bpmn.dataObject.input': <String>[
      'mxgraph.bpmn.dataInput',
      'mxgraph.bpmn.data_input',
      'mxgraph.bpmn.data-input',
    ],
    'bpmn.dataObject.output': <String>[
      'mxgraph.bpmn.dataOutput',
      'mxgraph.bpmn.data_output',
      'mxgraph.bpmn.data-output',
    ],
    'bpmn.dataStore': <String>[
      'mxgraph.bpmn.dataStore',
      'mxgraph.bpmn.data_store',
      'mxgraph.bpmn.data-store',
    ],
    'bpmn.message': <String>[
      'mxgraph.bpmn.message',
    ],
    'bpmn.group': <String>[
      'mxgraph.bpmn.group',
    ],
    'bpmn.annotation': <String>[
      'mxgraph.bpmn.annotation',
    ],
    'bpmn.pool': <String>[
      'mxgraph.bpmn.pool',
    ],
    'bpmn.lane': <String>[
      'mxgraph.bpmn.lane',
    ],
    'bpmn.pool.horizontal': <String>[
      'mxgraph.bpmn.poolHorizontal',
      'mxgraph.bpmn.pool_horizontal',
      'mxgraph.bpmn.pool-horizontal',
    ],
    'bpmn.lane.horizontal': <String>[
      'mxgraph.bpmn.laneHorizontal',
      'mxgraph.bpmn.lane_horizontal',
      'mxgraph.bpmn.lane-horizontal',
    ],
    'bpmn.pool.vertical': <String>[
      'mxgraph.bpmn.poolVertical',
      'mxgraph.bpmn.pool_vertical',
      'mxgraph.bpmn.pool-vertical',
    ],
    'bpmn.lane.vertical': <String>[
      'mxgraph.bpmn.laneVertical',
      'mxgraph.bpmn.lane_vertical',
      'mxgraph.bpmn.lane-vertical',
    ],
    'bpmn.textAnnotation': <String>[
      'mxgraph.bpmn.textAnnotation',
      'mxgraph.bpmn.text_annotation',
      'mxgraph.bpmn.text-annotation',
    ],
  };

  static const List<String> xmlDefinitions = <String>[
    // ── Events ──────────────────────────────────────────────────────────

    // 1. Start Event — thin circle
    r'''
<shape name="bpmn.startEvent" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<fillstroke />
</foreground>
</shape>
''',

    // 2. Start Event (Timer) — circle with clock hand
    r'''
<shape name="bpmn.startEvent.timer" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<fillstroke />
<path>
<move x="18" y="18" />
<line x="18" y="8" />
</path>
<stroke />
<path>
<move x="18" y="18" />
<line x="25" y="18" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 3. Start Event (Message) — circle with envelope
    r'''
<shape name="bpmn.startEvent.message" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<fillstroke />
<rect x="10" y="12" w="16" h="12" />
<stroke />
<path>
<move x="10" y="12" />
<line x="18" y="19" />
<line x="26" y="12" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 4. Start Event (Signal) — circle with triangle
    r'''
<shape name="bpmn.startEvent.signal" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<fillstroke />
<path>
<move x="18" y="10" />
<line x="26" y="25" />
<line x="10" y="25" />
<close />
</path>
<stroke />
</foreground>
</shape>
''',

    // 5. Intermediate Event — double circle
    r'''
<shape name="bpmn.intermediateEvent" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<fillstroke />
<ellipse x="4" y="4" w="28" h="28" />
<stroke />
</foreground>
</shape>
''',

    // 6. Intermediate Event (Message) — double circle with envelope
    r'''
<shape name="bpmn.intermediateEvent.message" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<fillstroke />
<ellipse x="4" y="4" w="28" h="28" />
<stroke />
<rect x="11" y="13" w="14" h="10" />
<stroke />
<path>
<move x="11" y="13" />
<line x="18" y="18" />
<line x="25" y="13" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 7. Intermediate Event (Signal) — double circle with triangle
    r'''
<shape name="bpmn.intermediateEvent.signal" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<fillstroke />
<ellipse x="4" y="4" w="28" h="28" />
<stroke />
<path>
<move x="18" y="11" />
<line x="25" y="24" />
<line x="11" y="24" />
<close />
</path>
<stroke />
</foreground>
</shape>
''',

    // 8. End Event — thick circle
    r'''
<shape name="bpmn.endEvent" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<strokewidth width="4" />
<fillstroke />
</foreground>
</shape>
''',

    // 9. End Event (Message) — thick circle with envelope
    r'''
<shape name="bpmn.endEvent.message" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<strokewidth width="4" />
<fillstroke />
<strokewidth width="1.5" />
<rect x="10" y="12" w="16" h="12" />
<stroke />
<path>
<move x="10" y="12" />
<line x="18" y="19" />
<line x="26" y="12" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 10. End Event (Terminate) — thick circle, filled black
    r'''
<shape name="bpmn.endEvent.terminate" w="36" h="36" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.15" y="0.15" perimeter="1" name="NW" />
<constraint x="0.15" y="0.85" perimeter="1" name="SW" />
<constraint x="0.85" y="0.15" perimeter="1" name="NE" />
<constraint x="0.85" y="0.85" perimeter="1" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="36" h="36" />
</background>
<foreground>
<strokewidth width="4" />
<fillstroke />
<ellipse x="9" y="9" w="18" h="18" />
<fillcolor color="#000000" />
<fillstroke />
</foreground>
</shape>
''',

    // ── Activities ──────────────────────────────────────────────────────

    // 11. Task — rounded rectangle
    r'''
<shape name="bpmn.task" w="100" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.02" y="0.02" perimeter="1" name="NW" />
<constraint x="0.02" y="0.98" perimeter="1" name="SW" />
<constraint x="0.98" y="0.02" perimeter="1" name="NE" />
<constraint x="0.98" y="0.98" perimeter="1" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="100" h="80" arcsize="10" />
</background>
<foreground>
<fillstroke />
</foreground>
</shape>
''',

    // 12. User Task — rounded rect with person icon (simplified)
    r'''
<shape name="bpmn.task.user" w="100" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.02" y="0.02" perimeter="1" name="NW" />
<constraint x="0.02" y="0.98" perimeter="1" name="SW" />
<constraint x="0.98" y="0.02" perimeter="1" name="NE" />
<constraint x="0.98" y="0.98" perimeter="1" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="100" h="80" arcsize="10" />
</background>
<foreground>
<fillstroke />
<path>
<move x="14" y="20" />
<arc rx="3" ry="3" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="17" y="17" />
<arc rx="3" ry="3" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="14" y="23" />
<arc rx="3" ry="3" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="14" y="20" />
<close />
</path>
<stroke />
<path>
<move x="9" y="30" />
<curve x1="9" y1="24" x2="19" y2="24" x3="19" y3="30" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 13. Service Task — rounded rect with gear (simplified circle with teeth)
    r'''
<shape name="bpmn.task.service" w="100" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.02" y="0.02" perimeter="1" name="NW" />
<constraint x="0.02" y="0.98" perimeter="1" name="SW" />
<constraint x="0.98" y="0.02" perimeter="1" name="NE" />
<constraint x="0.98" y="0.98" perimeter="1" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="100" h="80" arcsize="10" />
</background>
<foreground>
<fillstroke />
<ellipse x="6" y="14" w="14" h="14" />
<stroke />
<ellipse x="9" y="17" w="8" h="8" />
<stroke />
<path>
<move x="13" y="8" />
<line x="13" y="11" />
<move x="13" y="31" />
<line x="13" y="34" />
<move x="7" y="21" />
<line x="4" y="21" />
<move x="22" y="21" />
<line x="19" y="21" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 14. Send Task — rounded rect with filled envelope
    r'''
<shape name="bpmn.task.send" w="100" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.02" y="0.02" perimeter="1" name="NW" />
<constraint x="0.02" y="0.98" perimeter="1" name="SW" />
<constraint x="0.98" y="0.02" perimeter="1" name="NE" />
<constraint x="0.98" y="0.98" perimeter="1" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="100" h="80" arcsize="10" />
</background>
<foreground>
<fillstroke />
<rect x="4" y="14" w="18" h="14" />
<fillcolor color="#000000" />
<fillstroke />
<path>
<move x="4" y="14" />
<line x="13" y="21" />
<line x="22" y="14" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 15. Receive Task — rounded rect with envelope outline
    r'''
<shape name="bpmn.task.receive" w="100" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.02" y="0.02" perimeter="1" name="NW" />
<constraint x="0.02" y="0.98" perimeter="1" name="SW" />
<constraint x="0.98" y="0.02" perimeter="1" name="NE" />
<constraint x="0.98" y="0.98" perimeter="1" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="100" h="80" arcsize="10" />
</background>
<foreground>
<fillstroke />
<rect x="4" y="14" w="18" h="14" />
<stroke />
<path>
<move x="4" y="14" />
<line x="13" y="21" />
<line x="22" y="14" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 16. Manual Task — rounded rect with hand (simplified)
    r'''
<shape name="bpmn.task.manual" w="100" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.02" y="0.02" perimeter="1" name="NW" />
<constraint x="0.02" y="0.98" perimeter="1" name="SW" />
<constraint x="0.98" y="0.02" perimeter="1" name="NE" />
<constraint x="0.98" y="0.98" perimeter="1" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="100" h="80" arcsize="10" />
</background>
<foreground>
<fillstroke />
<path>
<move x="7" y="17" />
<line x="7" y="11" />
<arc rx="2" ry="2" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="11" y="11" />
<line x="11" y="17" />
<line x="11" y="9" />
<arc rx="2" ry="2" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="15" y="9" />
<line x="15" y="17" />
<line x="15" y="8" />
<arc rx="2" ry="2" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="19" y="8" />
<line x="19" y="18" />
<arc rx="4" ry="4" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="11" y="22" />
<close />
</path>
<stroke />
</foreground>
</shape>
''',

    // 17. Script Task — rounded rect with script lines
    r'''
<shape name="bpmn.task.script" w="100" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.02" y="0.02" perimeter="1" name="NW" />
<constraint x="0.02" y="0.98" perimeter="1" name="SW" />
<constraint x="0.98" y="0.02" perimeter="1" name="NE" />
<constraint x="0.98" y="0.98" perimeter="1" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="100" h="80" arcsize="10" />
</background>
<foreground>
<fillstroke />
<path>
<move x="4" y="14" />
<line x="7" y="11" />
<line x="19" y="11" />
<line x="16" y="14" />
<close />
</path>
<stroke />
<rect x="4" y="14" w="15" h="13" />
<stroke />
<path>
<move x="7" y="18" />
<line x="16" y="18" />
<move x="7" y="21" />
<line x="16" y="21" />
<move x="7" y="24" />
<line x="13" y="24" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 18. Sub-Process — rounded rect with plus sign at bottom border
    r'''
<shape name="bpmn.subProcess" w="100" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.02" y="0.02" perimeter="1" name="NW" />
<constraint x="0.02" y="0.98" perimeter="1" name="SW" />
<constraint x="0.98" y="0.02" perimeter="1" name="NE" />
<constraint x="0.98" y="0.98" perimeter="1" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="100" h="80" arcsize="10" />
</background>
<foreground>
<fillstroke />
<rect x="90" y="68" w="12" h="12" />
<fillstroke />
<path>
<move x="96" y="71" />
<line x="96" y="77" />
<move x="93" y="74" />
<line x="99" y="74" />
</path>
<stroke />
</foreground>
</shape>
''',

    // ── Gateways ────────────────────────────────────────────────────────

    // 19. Exclusive Gateway — diamond with X
    r'''
<shape name="bpmn.gateway.exclusive" w="50" h="50" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="25" y="0" />
<line x="50" y="25" />
<line x="25" y="50" />
<line x="0" y="25" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="17" y="17" />
<line x="33" y="33" />
<move x="33" y="17" />
<line x="17" y="33" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 20. Parallel Gateway — diamond with +
    r'''
<shape name="bpmn.gateway.parallel" w="50" h="50" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="25" y="0" />
<line x="50" y="25" />
<line x="25" y="50" />
<line x="0" y="25" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="25" y="13" />
<line x="25" y="37" />
<move x="13" y="25" />
<line x="37" y="25" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 21. Inclusive Gateway — diamond with O
    r'''
<shape name="bpmn.gateway.inclusive" w="50" h="50" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="25" y="0" />
<line x="50" y="25" />
<line x="25" y="50" />
<line x="0" y="25" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<ellipse x="14" y="14" w="22" h="22" />
<stroke />
</foreground>
</shape>
''',

    // 22. Event Gateway — diamond with double circle
    r'''
<shape name="bpmn.gateway.event" w="50" h="50" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="25" y="0" />
<line x="50" y="25" />
<line x="25" y="50" />
<line x="0" y="25" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<ellipse x="14" y="14" w="22" h="22" />
<stroke />
<ellipse x="18" y="18" w="14" h="14" />
<stroke />
</foreground>
</shape>
''',

    // 23. Complex Gateway — diamond with asterisk
    r'''
<shape name="bpmn.gateway.complex" w="50" h="50" aspect="fixed" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="25" y="0" />
<line x="50" y="25" />
<line x="25" y="50" />
<line x="0" y="25" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="25" y="13" />
<line x="25" y="37" />
<move x="13" y="25" />
<line x="37" y="25" />
<move x="16" y="16" />
<line x="34" y="34" />
<move x="34" y="16" />
<line x="16" y="34" />
</path>
<stroke />
</foreground>
</shape>
''',

    // ── Data ────────────────────────────────────────────────────────────

    // 24. Data Object — document shape
    r'''
<shape name="bpmn.dataObject" w="48" h="60" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="0" y="0" />
<line x="34" y="0" />
<line x="48" y="14" />
<line x="48" y="60" />
<line x="0" y="60" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="34" y="0" />
<line x="34" y="14" />
<line x="48" y="14" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 25. Data Object Input — document with input indicator
    r'''
<shape name="bpmn.dataObject.input" w="48" h="60" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="0" y="0" />
<line x="34" y="0" />
<line x="48" y="14" />
<line x="48" y="60" />
<line x="0" y="60" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="34" y="0" />
<line x="34" y="14" />
<line x="48" y="14" />
</path>
<stroke />
<path>
<move x="10" y="46" />
<arc rx="4" ry="4" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="10" y="54" />
<arc rx="4" ry="4" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="10" y="46" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 26. Data Object Output — document with output indicator
    r'''
<shape name="bpmn.dataObject.output" w="48" h="60" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="0" y="0" />
<line x="34" y="0" />
<line x="48" y="14" />
<line x="48" y="60" />
<line x="0" y="60" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="34" y="0" />
<line x="34" y="14" />
<line x="48" y="14" />
</path>
<stroke />
<rect x="7" y="47" w="6" h="6" />
<fillcolor color="#000000" />
<fillstroke />
</foreground>
</shape>
''',

    // 27. Data Store — cylinder shape
    r'''
<shape name="bpmn.dataStore" w="60" h="60" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="0" y="10" />
<arc rx="30" ry="10" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="60" y="10" />
<line x="60" y="50" />
<arc rx="30" ry="10" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0" y="50" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="0" y="10" />
<arc rx="30" ry="10" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="60" y="10" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 28. Message — envelope shape
    r'''
<shape name="bpmn.message" w="48" h="32" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="0" y="0" />
<line x="48" y="0" />
<line x="48" y="32" />
<line x="0" y="32" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="0" y="0" />
<line x="24" y="18" />
<line x="48" y="0" />
</path>
<stroke />
</foreground>
</shape>
''',

    // 29. Group — dashed rounded rectangle
    r'''
<shape name="bpmn.group" w="120" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
<constraint x="0.02" y="0.02" perimeter="1" name="NW" />
<constraint x="0.02" y="0.98" perimeter="1" name="SW" />
<constraint x="0.98" y="0.02" perimeter="1" name="NE" />
<constraint x="0.98" y="0.98" perimeter="1" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="120" h="80" arcsize="8" />
</background>
<foreground>
<fillstroke />
</foreground>
</shape>
''',

    // ── Connectors & Artifacts ──────────────────────────────────────────

    // 30. Annotation — bracket annotation (left bracket)
    r'''
<shape name="bpmn.annotation" w="20" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="20" y="0" />
<line x="5" y="0" />
<line x="5" y="80" />
<line x="20" y="80" />
</path>
</background>
<foreground>
<stroke />
</foreground>
</shape>
''',

    // 31. Pool — horizontal swim lane
    r'''
<shape name="bpmn.pool" w="400" h="80" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="20" y="0" />
<line x="400" y="0" />
<line x="400" y="80" />
<line x="20" y="80" />
<line x="20" y="0" />
<close />
<move x="20" y="0" />
<line x="0" y="0" />
<line x="0" y="80" />
<line x="20" y="80" />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>
''',

    // 32. Lane — vertical lane divider
    r'''
<shape name="bpmn.lane" w="400" h="100" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="20" y="0" />
<line x="400" y="0" />
<line x="400" y="100" />
<line x="20" y="100" />
<line x="20" y="0" />
<close />
<move x="20" y="0" />
<line x="0" y="0" />
<line x="0" y="100" />
<line x="20" y="100" />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>
''',

    // ── Swimlanes ───────────────────────────────────────────────────────

    // 33. Horizontal Pool
    r'''
<shape name="bpmn.pool.horizontal" w="500" h="100" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="25" y="0" />
<line x="500" y="0" />
<line x="500" y="100" />
<line x="25" y="100" />
<line x="25" y="0" />
<close />
<move x="25" y="0" />
<line x="0" y="0" />
<line x="0" y="100" />
<line x="25" y="100" />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>
''',

    // 34. Horizontal Lane
    r'''
<shape name="bpmn.lane.horizontal" w="500" h="100" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="25" y="0" />
<line x="500" y="0" />
<line x="500" y="100" />
<line x="25" y="100" />
<line x="25" y="0" />
<close />
<move x="25" y="0" />
<line x="0" y="0" />
<line x="0" y="100" />
<line x="25" y="100" />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>
''',

    // 35. Vertical Pool
    r'''
<shape name="bpmn.pool.vertical" w="100" h="500" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="0" y="25" />
<line x="0" y="500" />
<line x="100" y="500" />
<line x="100" y="25" />
<line x="0" y="25" />
<close />
<move x="0" y="25" />
<line x="0" y="0" />
<line x="100" y="0" />
<line x="100" y="25" />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>
''',

    // 36. Vertical Lane
    r'''
<shape name="bpmn.lane.vertical" w="100" h="500" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="0" y="25" />
<line x="0" y="500" />
<line x="100" y="500" />
<line x="100" y="25" />
<line x="0" y="25" />
<close />
<move x="0" y="25" />
<line x="0" y="0" />
<line x="100" y="0" />
<line x="100" y="25" />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>
''',

    // 37. Text Annotation — text with bracket connector
    r'''
<shape name="bpmn.textAnnotation" w="100" h="60" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
<path>
<move x="100" y="0" />
<line x="10" y="0" />
<line x="10" y="60" />
<line x="100" y="60" />
</path>
</background>
<foreground>
<stroke />
</foreground>
</shape>
''',
  ];
}
