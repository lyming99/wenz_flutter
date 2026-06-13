// Generated from drawio/src/main/webapp/stencils/flowchart.xml.
// Keep XML close to the upstream stencil definitions for easier future refreshes.

class FlowchartStencils {
  const FlowchartStencils._();

  static const List<String> xmlDefinitions = <String>[
    // Annotation 1
    r'''
<shape name="flowchart.annotation1" h="98" w="50" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0" y="0" perimeter="0" name="NW" />
<constraint x="0" y="1" perimeter="0" name="SW" />
<constraint x="1" y="0" perimeter="0" name="NE" />
<constraint x="1" y="1" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="50" y="0" />
<line x="0" y="0" />
<line x="0" y="98" />
<line x="50" y="98" />
</path>
</background>
<foreground>
<stroke />
</foreground>
</shape>

''',
    // Annotation 2
    r'''
<shape name="flowchart.annotation2" h="98" w="100" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="1" y="0" perimeter="0" name="NE" />
<constraint x="1" y="1" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="100" y="0" />
<line x="50" y="0" />
<line x="50" y="98" />
<line x="100" y="98" />
</path>
</background>
<foreground>
<stroke />
<path>
<move x="0" y="49" />
<line x="50" y="49" />
</path>
<stroke />
</foreground>
</shape>

''',
    // Card
    r'''
<shape name="flowchart.card" h="60" w="98" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.1" y="0.16" perimeter="0" name="NW" />
<constraint x="0.015" y="0.98" perimeter="0" name="SW" />
<constraint x="0.985" y="0.02" perimeter="0" name="NE" />
<constraint x="0.985" y="0.98" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="19" y="0" />
<line x="93" y="0" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="98" y="5" />
<line x="98" y="55" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="93" y="60" />
<line x="5" y="60" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0" y="55" />
<line x="0" y="20" />
<line x="19" y="0" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Collate
    r'''
<shape name="flowchart.collate" h="98" w="96.82" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.02" perimeter="0" name="NW" />
<constraint x="0" y="0.98" perimeter="0" name="SW" />
<constraint x="1" y="0.02" perimeter="0" name="NE" />
<constraint x="1" y="0.98" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="92.41" y="0" />
<arc rx="6" ry="3.5" x-axis-rotation="-15" large-arc-flag="0" sweep-flag="1" x="95.41" y="5" />
<line x="1.41" y="93" />
<arc rx="6" ry="3.5" x-axis-rotation="-15" large-arc-flag="0" sweep-flag="0" x="4.41" y="98" />
<line x="92.41" y="98" />
<arc rx="6" ry="3.5" x-axis-rotation="15" large-arc-flag="0" sweep-flag="0" x="95.41" y="93" />
<line x="1.41" y="5" />
<arc rx="6" ry="3.5" x-axis-rotation="15" large-arc-flag="0" sweep-flag="1" x="4.41" y="0" />
<line x="92.41" y="0" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Data
    r'''
<shape name="flowchart.data" h="60.24" w="98.77" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0.095" y="0.5" perimeter="0" name="W" />
<constraint x="0.905" y="0.5" perimeter="0" name="E" />
<constraint x="0.23" y="0.02" perimeter="0" name="NW" />
<constraint x="0.015" y="0.98" perimeter="0" name="SW" />
<constraint x="0.985" y="0.02" perimeter="0" name="NE" />
<constraint x="0.77" y="0.98" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="19.37" y="5.12" />
<arc rx="6" ry="12" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="24.37" y="0.12" />
<line x="93.37" y="0.12" />
<arc rx="5" ry="4" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="98.37" y="5.12" />
<line x="79.37" y="55.12" />
<arc rx="6" ry="12" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="74.37" y="60.12" />
<line x="4.37" y="60.12" />
<arc rx="5" ry="4" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0.37" y="55.12" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Database
    r'''
<shape name="flowchart.database" h="60" w="60" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0" y="0.15" perimeter="0" name="NW" />
<constraint x="0" y="0.85" perimeter="0" name="SW" />
<constraint x="1" y="0.15" perimeter="0" name="NE" />
<constraint x="1" y="0.85" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="0" y="50" />
<line x="0" y="10" />
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
    // Decision
    r'''
<shape name="flowchart.decision" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
</connections>
<background>
<path>
<move x="50" y="0" />
<line x="100" y="50" />
<line x="50" y="100" />
<line x="0" y="50" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Delay
    r'''
<shape name="flowchart.delay" h="60" w="98.25" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.02" y="0.015" perimeter="0" name="NW" />
<constraint x="0.02" y="0.985" perimeter="0" name="SW" />
<constraint x="0.81" y="0" perimeter="0" name="NE" />
<constraint x="0.81" y="1" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="0" y="5" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="5" y="0" />
<line x="79" y="0" />
<arc rx="33" ry="33" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="79" y="60" />
<line x="5" y="60" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0" y="55" />
<line x="0" y="5" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Direct Data
    r'''
<shape name="flowchart.directData" h="60" w="98" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.08" y="0" perimeter="0" name="NW" />
<constraint x="0.08" y="1" perimeter="0" name="SW" />
<constraint x="0.91" y="0" perimeter="0" name="NE" />
<constraint x="0.91" y="1" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="9" y="0" />
<line x="89" y="0" />
<arc rx="9" ry="30" x-axis-rotation="0" large-arc-flag="1" sweep-flag="1" x="89" y="60" />
<line x="9" y="60" />
<arc rx="9" ry="30" x-axis-rotation="0" large-arc-flag="1" sweep-flag="1" x="9" y="0" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="89" y="0" />
<arc rx="9" ry="30" x-axis-rotation="0" large-arc-flag="1" sweep-flag="0" x="89" y="60" />
</path>
<stroke />
</foreground>
</shape>

''',
    // Display
    r'''
<shape name="flowchart.display" h="60" w="98.25" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.2" y="0.14" perimeter="0" name="NW" />
<constraint x="0.2" y="0.86" perimeter="0" name="SW" />
<constraint x="0.92" y="0.14" perimeter="0" name="NE" />
<constraint x="0.92" y="0.86" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="0" y="30" />
<arc rx="60" ry="60" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="39" y="0" />
<line x="79" y="0" />
<arc rx="33" ry="33" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="79" y="60" />
<line x="39" y="60" />
<arc rx="60" ry="60" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0" y="30" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Document
    r'''
<shape name="flowchart.document" h="60.9" w="98" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="0.9" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.02" y="0.015" perimeter="0" name="NW" />
<constraint x="0" y="0.9" perimeter="0" name="SW" />
<constraint x="0.98" y="0.015" perimeter="0" name="NE" />
<constraint x="1" y="0.9" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="0" y="5" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="5" y="0" />
<line x="93" y="0" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="98" y="5" />
<line x="98" y="55" />
<arc rx="70" ry="70" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="49" y="55" />
<arc rx="70" ry="70" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0" y="55" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Extract or Measurement
    r'''
<shape aspect="variable" h="60.84" name="flowchart.extractOrMeasurement" strokewidth="inherit" w="95.01">
    <connections>
        <constraint name="N" perimeter="0" x="0.5" y="0" />
        <constraint name="S" perimeter="0" x="0.5" y="1" />
        <constraint name="W" perimeter="0" x="0.22" y="0.5" />
        <constraint name="E" perimeter="0" x="0.78" y="0.5" />
        <constraint name="SW" perimeter="0" x="0.01" y="0.97" />
        <constraint name="SE" perimeter="0" x="0.99" y="0.97" />
    </connections>
    <background>
        <path>
            <move x="3.5" y="60.84" />
            <line x="91.5" y="60.84" />
            <arc large-arc-flag="0" rx="3.5" ry="3.5" sweep-flag="0" x="94.5" x-axis-rotation="0" y="55.84" />
            <line x="49.5" y="0.84" />
            <arc large-arc-flag="0" rx="3.5" ry="3.5" sweep-flag="0" x="45.5" x-axis-rotation="0" y="0.84" />
            <line x="0.5" y="55.84" />
            <arc large-arc-flag="0" rx="3.5" ry="3.5" sweep-flag="0" x="3.5" x-axis-rotation="0" y="60.84" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Internal Storage
    r'''
<shape name="flowchart.internalStorage" h="70" w="70" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.02" y="0.015" perimeter="0" name="NW" />
<constraint x="0.02" y="0.985" perimeter="0" name="SW" />
<constraint x="0.98" y="0.015" perimeter="0" name="NE" />
<constraint x="0.98" y="0.985" perimeter="0" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="70" h="70" arcsize="7.143" />
</background>
<foreground>
<fillstroke />
<path>
<move x="0" y="15" />
<line x="70" y="15" />
</path>
<stroke />
<path>
<move x="15" y="0" />
<line x="15" y="70" />
</path>
<stroke />
</foreground>
</shape>

''',
    // Loop Limit
    r'''
<shape name="flowchart.loopLimit" h="60" w="98" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.1" y="0.15" perimeter="0" name="NW" />
<constraint x="0.02" y="0.985" perimeter="0" name="SW" />
<constraint x="0.9" y="0.15" perimeter="0" name="NE" />
<constraint x="0.98" y="0.985" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="19" y="0" />
<line x="79" y="0" />
<line x="98" y="20" />
<line x="98" y="55" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="93" y="60" />
<line x="5" y="60" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0" y="55" />
<line x="0" y="20" />
<line x="19" y="0" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Manual Input
    r'''
<shape name="flowchart.manualInput" h="60" w="98.05" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0.195" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.02" y="0.985" perimeter="0" name="SW" />
<constraint x="0.98" y="0.015" perimeter="0" name="NE" />
<constraint x="0.98" y="0.985" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="0" y="28.73" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="3.7" y="24" />
<line x="91.7" y="0.17" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="98" y="5" />
<line x="98" y="55" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="94" y="60" />
<line x="5" y="60" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0" y="55" />
<line x="0" y="28.73" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Manual Operation
    r'''
<shape name="flowchart.manualOperation" h="60.04" w="98.79" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0.1" y="0.5" perimeter="0" name="W" />
<constraint x="0.9" y="0.5" perimeter="0" name="E" />
<constraint x="0.02" y="0.015" perimeter="0" name="NW" />
<constraint x="0.22" y="0.985" perimeter="0" name="SW" />
<constraint x="0.98" y="0.015" perimeter="0" name="NE" />
<constraint x="0.78" y="0.985" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="0.39" y="5.04" />
<arc rx="5" ry="4" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="5.39" y="0.04" />
<line x="93.39" y="0.04" />
<arc rx="5" ry="4" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="98.39" y="5.04" />
<line x="79.39" y="55.04" />
<arc rx="6.5" ry="6.5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="74.39" y="60.04" />
<line x="24.39" y="60.04" />
<arc rx="6.5" ry="6.5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="19.39" y="55.04" />
<line x="0.39" y="5.04" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Merge or Storage
    r'''
<shape aspect="variable" h="60.84" name="flowchart.mergeOrStorage" strokewidth="inherit" w="95.01">
    <connections>
        <constraint name="N" perimeter="0" x="0.5" y="0" />
        <constraint name="S" perimeter="0" x="0.5" y="1" />
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
        <constraint name="NW" perimeter="0" x="0" y="0" />
        <constraint name="SW" perimeter="0" x="0" y="1" />
        <constraint name="NE" perimeter="0" x="1" y="0" />
        <constraint name="SE" perimeter="0" x="1" y="1" />
    </connections>
    <background>
        <path>
            <move x="3.5" y="0" />
            <line x="91.5" y="0" />
            <arc large-arc-flag="0" rx="3.5" ry="3.5" sweep-flag="1" x="94.5" x-axis-rotation="0" y="5" />
            <line x="49.5" y="60" />
            <arc large-arc-flag="0" rx="3.5" ry="3.5" sweep-flag="1" x="45.5" x-axis-rotation="0" y="60" />
            <line x="0.5" y="5" />
            <arc large-arc-flag="0" rx="3.5" ry="3.5" sweep-flag="1" x="3.5" x-axis-rotation="0" y="0" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Multi-Document
    r'''
<shape name="flowchart.multiDocument" h="60.28" w="88" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="0.88" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.08" y="0.1" perimeter="0" name="NW" />
<constraint x="0" y="0.91" perimeter="0" name="SW" />
<constraint x="0.98" y="0.02" perimeter="0" name="NE" />
<constraint x="0.885" y="0.91" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="10" y="5" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="15" y="0" />
<line x="83" y="0" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="88" y="5" />
<line x="88" y="45" />
<arc rx="50" ry="50" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="49" y="45" />
<arc rx="50" ry="50" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="10" y="45" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="5" y="10" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="10" y="5" />
<line x="78" y="5" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="83" y="10" />
<line x="83" y="50" />
<arc rx="50" ry="50" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="44" y="50" />
<arc rx="50" ry="50" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="5" y="50" />
<close />
</path>
<fillstroke />
<path>
<move x="0" y="15" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="5" y="10" />
<line x="73" y="10" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="78" y="15" />
<line x="78" y="55" />
<arc rx="50" ry="50" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="39" y="55" />
<arc rx="50" ry="50" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0" y="55" />
<close />
</path>
<fillstroke />
</foreground>
</shape>

''',
    // Off-page Reference
    r'''
<shape name="flowchart.offPageReference" h="60" w="60" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0" y="0" perimeter="0" name="NW" />
<constraint x="1" y="0" perimeter="0" name="NE" />
</connections>
<background>
<path>
<move x="0" y="0" />
<line x="60" y="0" />
<line x="60" y="30" />
<line x="30" y="60" />
<line x="0" y="30" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // On-page Reference
    r'''
<shape name="flowchart.onPageReference" h="60" w="60" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.145" y="0.145" perimeter="0" name="NW" />
<constraint x="0.145" y="0.855" perimeter="0" name="SW" />
<constraint x="0.855" y="0.145" perimeter="0" name="NE" />
<constraint x="0.855" y="0.855" perimeter="0" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="60" h="60" />
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Or
    r'''
<shape name="flowchart.or" h="70" w="70" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.145" y="0.145" perimeter="0" name="NW" />
<constraint x="0.145" y="0.855" perimeter="0" name="SW" />
<constraint x="0.855" y="0.145" perimeter="0" name="NE" />
<constraint x="0.855" y="0.855" perimeter="0" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="70" h="70" />
</background>
<foreground>
<fillstroke />
<path>
<move x="10" y="60" />
<line x="60" y="10" />
</path>
<stroke />
<path>
<move x="10" y="10" />
<line x="60" y="60" />
</path>
<stroke />
</foreground>
</shape>

''',
    // Paper Tape
    r'''
<shape name="flowchart.paperTape" h="61.81" w="98" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0.09" perimeter="0" name="N" />
<constraint x="0.5" y="0.91" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0" y="0.09" perimeter="0" name="NW" />
<constraint x="0" y="0.91" perimeter="0" name="SW" />
<constraint x="1" y="0.09" perimeter="0" name="NE" />
<constraint x="1" y="0.91" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="0" y="5.9" />
<arc rx="70" ry="70" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="49" y="5.9" />
<arc rx="70" ry="70" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="98" y="5.9" />
<line x="98" y="55.9" />
<arc rx="70" ry="70" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="49" y="55.9" />
<arc rx="70" ry="70" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0" y="55.9" />
<line x="0" y="5.9" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Parallel Mode
    r'''
<shape name="flowchart.parallelMode" h="40" w="94" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0" y="0" perimeter="0" name="NW" />
<constraint x="0" y="1" perimeter="0" name="SW" />
<constraint x="1" y="0" perimeter="0" name="NE" />
<constraint x="1" y="1" perimeter="0" name="SE" />
</connections>
<background>
<save />
<fillcolor color="accentColor" default="#ffff00" />
<path>
<move x="47" y="15" />
<line x="52" y="20" />
<line x="47" y="25" />
<line x="42" y="20" />
<line x="47" y="15" />
<close />
<move x="27" y="15" />
<line x="32" y="20" />
<line x="27" y="25" />
<line x="22" y="20" />
<line x="27" y="15" />
<close />
<move x="67" y="15" />
<line x="72" y="20" />
<line x="67" y="25" />
<line x="62" y="20" />
<line x="67" y="15" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<restore />
<path>
<move x="0" y="0" />
<line x="94" y="0" />
</path>
<stroke />
<path>
<move x="0" y="40" />
<line x="94" y="40" />
</path>
<stroke />
</foreground>
</shape>

''',
    // Predefined Process
    r'''
<shape name="flowchart.predefinedProcess" h="60" w="98" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.02" y="0.015" perimeter="0" name="NW" />
<constraint x="0.02" y="0.985" perimeter="0" name="SW" />
<constraint x="0.98" y="0.015" perimeter="0" name="NE" />
<constraint x="0.98" y="0.985" perimeter="0" name="SE" />
</connections>
<background>
<roundrect x="0" y="0" w="98" h="60" arcsize="6.718" />
</background>
<foreground>
<fillstroke />
<path>
<move x="14" y="0" />
<line x="14" y="60" />
</path>
<stroke />
<path>
<move x="84" y="0" />
<line x="84" y="60" />
</path>
<stroke />
</foreground>
</shape>

''',
    // Preparation
    r'''
<shape name="flowchart.preparation" h="60" w="97.11" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.26" y="0.02" perimeter="0" name="NW" />
<constraint x="0.26" y="0.98" perimeter="0" name="SW" />
<constraint x="0.74" y="0.02" perimeter="0" name="NE" />
<constraint x="0.74" y="0.98" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="20.56" y="5" />
<arc rx="15" ry="15" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="31.56" y="0" />
<line x="65.56" y="0" />
<arc rx="15" ry="15" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="76.56" y="5" />
<line x="96.56" y="28" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="96.56" y="32" />
<line x="76.56" y="55" />
<arc rx="15" ry="15" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="65.56" y="60" />
<line x="31.56" y="60" />
<arc rx="15" ry="15" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="20.56" y="55" />
<line x="0.56" y="32" />
<arc rx="5" ry="5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="0.56" y="28" />
<line x="20.56" y="5" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Process
    r'''
<shape name="flowchart.process" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
</connections>
<background>
<roundrect x="0" y="0" w="100" h="100" arcsize="6" />
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Sequential Data
    r'''
<shape name="flowchart.sequentialData" h="99" w="99" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.145" y="0.145" perimeter="0" name="NW" />
<constraint x="0.145" y="0.855" perimeter="0" name="SW" />
<constraint x="0.855" y="0.145" perimeter="0" name="NE" />
<constraint x="1" y="1" perimeter="0" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="99" h="99" />
</background>
<foreground>
<fillstroke />
<path>
<move x="49.5" y="99" />
<line x="99" y="99" />
</path>
<stroke />
</foreground>
</shape>

''',
    // Sort
    r'''
<shape name="flowchart.sort" h="98" w="98" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
</connections>
<background>
<path>
<move x="51" y="1" />
<line x="97" y="47" />
<arc rx="2.5" ry="2.5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="97" y="51" />
<line x="51" y="97" />
<arc rx="2.5" ry="2.5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="47" y="97" />
<line x="1" y="51" />
<arc rx="2.5" ry="2.5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="1" y="47" />
<line x="47" y="1" />
<arc rx="2.5" ry="2.5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="51" y="1" />
<close />
</path>
</background>
<foreground>
<fillstroke />
<path>
<move x="0" y="49" />
<line x="98" y="49" />
</path>
<stroke />
</foreground>
</shape>

''',
    // Start 1
    r'''
<shape name="flowchart.start1" h="60" w="99" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.145" y="0.145" perimeter="0" name="NW" />
<constraint x="0.145" y="0.855" perimeter="0" name="SW" />
<constraint x="0.855" y="0.145" perimeter="0" name="NE" />
<constraint x="0.855" y="0.855" perimeter="0" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="99" h="60" />
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Start 2
    r'''
<shape name="flowchart.start2" h="99" w="99" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.145" y="0.145" perimeter="0" name="NW" />
<constraint x="0.145" y="0.855" perimeter="0" name="SW" />
<constraint x="0.855" y="0.145" perimeter="0" name="NE" />
<constraint x="0.855" y="0.855" perimeter="0" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="99" h="99" />
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Stored Data
    r'''
<shape name="flowchart.storedData" h="60" w="96.51" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="0.93" y="0.5" perimeter="0" name="E" />
<constraint x="0.1" y="0" perimeter="0" name="NW" />
<constraint x="0.1" y="1" perimeter="0" name="SW" />
<constraint x="0.995" y="0.01" perimeter="0" name="NE" />
<constraint x="0.995" y="0.99" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="10" y="0" />
<line x="96" y="0" />
<arc rx="1.5" ry="1.5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="96" y="2" />
<arc rx="10" ry="30" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="96" y="58" />
<arc rx="1.5" ry="1.5" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="96" y="60" />
<line x="10" y="60" />
<arc rx="10" ry="30" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="10" y="0" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Summing Function
    r'''
<shape name="flowchart.summingFunction" h="70" w="70" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.145" y="0.145" perimeter="0" name="NW" />
<constraint x="0.145" y="0.855" perimeter="0" name="SW" />
<constraint x="0.855" y="0.145" perimeter="0" name="NE" />
<constraint x="0.855" y="0.855" perimeter="0" name="SE" />
</connections>
<background>
<ellipse x="0" y="0" w="70" h="70" />
</background>
<foreground>
<fillstroke />
<path>
<move x="0" y="35" />
<line x="70" y="35" />
</path>
<stroke />
<path>
<move x="35" y="0" />
<line x="35" y="70" />
</path>
<stroke />
</foreground>
</shape>

''',
    // Terminator
    r'''
<shape name="flowchart.terminator" h="60" w="98" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="0" name="N" />
<constraint x="0.5" y="1" perimeter="0" name="S" />
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
<constraint x="0.11" y="0.11" perimeter="0" name="NW" />
<constraint x="0.11" y="0.89" perimeter="0" name="SW" />
<constraint x="0.89" y="0.11" perimeter="0" name="NE" />
<constraint x="0.89" y="0.89" perimeter="0" name="SE" />
</connections>
<background>
<path>
<move x="30" y="0" />
<line x="68" y="0" />
<arc rx="30" ry="30" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="68" y="60" />
<line x="30" y="60" />
<arc rx="30" ry="30" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="30" y="0" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
    // Transfer
    r'''
<shape name="flowchart.transfer" h="70" w="97.5" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0" y="0.5" perimeter="0" name="W" />
<constraint x="1" y="0.5" perimeter="0" name="E" />
</connections>
<background>
<path>
<move x="0" y="20" />
<line x="59" y="20" />
<line x="59" y="0" />
<line x="97.5" y="35" />
<line x="59" y="70" />
<line x="59" y="50" />
<line x="0" y="50" />
<close />
</path>
</background>
<foreground>
<fillstroke />
</foreground>
</shape>

''',
  ];

  static const Map<String, List<String>> aliases = <String, List<String>>{
    'flowchart.annotation1': <String>[
      'mxgraph.flowchart.annotation1',
      'mxgraph.flowchart.annotation_1',
      'mxgraph.flowchart.annotation-1',
      'stencil.annotation1',
    ],
    'flowchart.annotation2': <String>[
      'mxgraph.flowchart.annotation2',
      'mxgraph.flowchart.annotation_2',
      'mxgraph.flowchart.annotation-2',
      'stencil.annotation2',
    ],
    'flowchart.card': <String>[
      'mxgraph.flowchart.card',
      'mxgraph.flowchart.card',
      'mxgraph.flowchart.card',
      'stencil.card',
    ],
    'flowchart.collate': <String>[
      'mxgraph.flowchart.collate',
      'mxgraph.flowchart.collate',
      'mxgraph.flowchart.collate',
      'stencil.collate',
    ],
    'flowchart.data': <String>[
      'mxgraph.flowchart.data',
      'mxgraph.flowchart.data',
      'mxgraph.flowchart.data',
      'stencil.data',
    ],
    'flowchart.database': <String>[
      'mxgraph.flowchart.database',
      'mxgraph.flowchart.database',
      'mxgraph.flowchart.database',
      'stencil.database',
    ],
    'flowchart.decision': <String>[
      'mxgraph.flowchart.decision',
      'mxgraph.flowchart.decision',
      'mxgraph.flowchart.decision',
      'stencil.decision',
    ],
    'flowchart.delay': <String>[
      'mxgraph.flowchart.delay',
      'mxgraph.flowchart.delay',
      'mxgraph.flowchart.delay',
      'stencil.delay',
    ],
    'flowchart.directData': <String>[
      'mxgraph.flowchart.directData',
      'mxgraph.flowchart.direct_data',
      'mxgraph.flowchart.direct-data',
      'stencil.directData',
    ],
    'flowchart.display': <String>[
      'mxgraph.flowchart.display',
      'mxgraph.flowchart.display',
      'mxgraph.flowchart.display',
      'stencil.display',
    ],
    'flowchart.document': <String>[
      'mxgraph.flowchart.document',
      'mxgraph.flowchart.document',
      'mxgraph.flowchart.document',
      'stencil.document',
    ],
    'flowchart.extractOrMeasurement': <String>[
      'mxgraph.flowchart.extractOrMeasurement',
      'mxgraph.flowchart.extract_or_measurement',
      'mxgraph.flowchart.extract-or-measurement',
      'stencil.extractOrMeasurement',
    ],
    'flowchart.internalStorage': <String>[
      'mxgraph.flowchart.internalStorage',
      'mxgraph.flowchart.internal_storage',
      'mxgraph.flowchart.internal-storage',
      'stencil.internalStorage',
    ],
    'flowchart.loopLimit': <String>[
      'mxgraph.flowchart.loopLimit',
      'mxgraph.flowchart.loop_limit',
      'mxgraph.flowchart.loop-limit',
      'stencil.loopLimit',
    ],
    'flowchart.manualInput': <String>[
      'mxgraph.flowchart.manualInput',
      'mxgraph.flowchart.manual_input',
      'mxgraph.flowchart.manual-input',
      'stencil.manualInput',
    ],
    'flowchart.manualOperation': <String>[
      'mxgraph.flowchart.manualOperation',
      'mxgraph.flowchart.manual_operation',
      'mxgraph.flowchart.manual-operation',
      'stencil.manualOperation',
    ],
    'flowchart.mergeOrStorage': <String>[
      'mxgraph.flowchart.mergeOrStorage',
      'mxgraph.flowchart.merge_or_storage',
      'mxgraph.flowchart.merge-or-storage',
      'stencil.mergeOrStorage',
    ],
    'flowchart.multiDocument': <String>[
      'mxgraph.flowchart.multiDocument',
      'mxgraph.flowchart.multi_document',
      'mxgraph.flowchart.multi-document',
      'stencil.multiDocument',
    ],
    'flowchart.offPageReference': <String>[
      'mxgraph.flowchart.offPageReference',
      'mxgraph.flowchart.off_page_reference',
      'mxgraph.flowchart.off-page-reference',
      'stencil.offPageReference',
    ],
    'flowchart.onPageReference': <String>[
      'mxgraph.flowchart.onPageReference',
      'mxgraph.flowchart.on_page_reference',
      'mxgraph.flowchart.on-page-reference',
      'stencil.onPageReference',
    ],
    'flowchart.or': <String>[
      'mxgraph.flowchart.or',
      'mxgraph.flowchart.or',
      'mxgraph.flowchart.or',
      'stencil.or',
    ],
    'flowchart.paperTape': <String>[
      'mxgraph.flowchart.paperTape',
      'mxgraph.flowchart.paper_tape',
      'mxgraph.flowchart.paper-tape',
      'stencil.paperTape',
    ],
    'flowchart.parallelMode': <String>[
      'mxgraph.flowchart.parallelMode',
      'mxgraph.flowchart.parallel_mode',
      'mxgraph.flowchart.parallel-mode',
      'stencil.parallelMode',
    ],
    'flowchart.predefinedProcess': <String>[
      'mxgraph.flowchart.predefinedProcess',
      'mxgraph.flowchart.predefined_process',
      'mxgraph.flowchart.predefined-process',
      'stencil.predefinedProcess',
    ],
    'flowchart.preparation': <String>[
      'mxgraph.flowchart.preparation',
      'mxgraph.flowchart.preparation',
      'mxgraph.flowchart.preparation',
      'stencil.preparation',
    ],
    'flowchart.process': <String>[
      'mxgraph.flowchart.process',
      'mxgraph.flowchart.process',
      'mxgraph.flowchart.process',
      'stencil.process',
    ],
    'flowchart.sequentialData': <String>[
      'mxgraph.flowchart.sequentialData',
      'mxgraph.flowchart.sequential_data',
      'mxgraph.flowchart.sequential-data',
      'stencil.sequentialData',
    ],
    'flowchart.sort': <String>[
      'mxgraph.flowchart.sort',
      'mxgraph.flowchart.sort',
      'mxgraph.flowchart.sort',
      'stencil.sort',
    ],
    'flowchart.start1': <String>[
      'mxgraph.flowchart.start1',
      'mxgraph.flowchart.start_1',
      'mxgraph.flowchart.start-1',
      'stencil.start1',
    ],
    'flowchart.start2': <String>[
      'mxgraph.flowchart.start2',
      'mxgraph.flowchart.start_2',
      'mxgraph.flowchart.start-2',
      'stencil.start2',
    ],
    'flowchart.storedData': <String>[
      'mxgraph.flowchart.storedData',
      'mxgraph.flowchart.stored_data',
      'mxgraph.flowchart.stored-data',
      'stencil.storedData',
    ],
    'flowchart.summingFunction': <String>[
      'mxgraph.flowchart.summingFunction',
      'mxgraph.flowchart.summing_function',
      'mxgraph.flowchart.summing-function',
      'stencil.summingFunction',
    ],
    'flowchart.terminator': <String>[
      'mxgraph.flowchart.terminator',
      'mxgraph.flowchart.terminator',
      'mxgraph.flowchart.terminator',
      'stencil.terminator',
    ],
    'flowchart.transfer': <String>[
      'mxgraph.flowchart.transfer',
      'mxgraph.flowchart.transfer',
      'mxgraph.flowchart.transfer',
      'stencil.transfer',
    ],
  };

  static const List<String> keys = <String>[
    'flowchart.annotation1',
    'flowchart.annotation2',
    'flowchart.card',
    'flowchart.collate',
    'flowchart.data',
    'flowchart.database',
    'flowchart.decision',
    'flowchart.delay',
    'flowchart.directData',
    'flowchart.display',
    'flowchart.document',
    'flowchart.extractOrMeasurement',
    'flowchart.internalStorage',
    'flowchart.loopLimit',
    'flowchart.manualInput',
    'flowchart.manualOperation',
    'flowchart.mergeOrStorage',
    'flowchart.multiDocument',
    'flowchart.offPageReference',
    'flowchart.onPageReference',
    'flowchart.or',
    'flowchart.paperTape',
    'flowchart.parallelMode',
    'flowchart.predefinedProcess',
    'flowchart.preparation',
    'flowchart.process',
    'flowchart.sequentialData',
    'flowchart.sort',
    'flowchart.start1',
    'flowchart.start2',
    'flowchart.storedData',
    'flowchart.summingFunction',
    'flowchart.terminator',
    'flowchart.transfer',
  ];

  static const Map<String, String> labels = <String, String>{
    'flowchart.annotation1': 'Annotation 1',
    'flowchart.annotation2': 'Annotation 2',
    'flowchart.card': 'Card',
    'flowchart.collate': 'Collate',
    'flowchart.data': 'Data',
    'flowchart.database': 'Database',
    'flowchart.decision': 'Decision',
    'flowchart.delay': 'Delay',
    'flowchart.directData': 'Direct Data',
    'flowchart.display': 'Display',
    'flowchart.document': 'Document',
    'flowchart.extractOrMeasurement': 'Extract or Measurement',
    'flowchart.internalStorage': 'Internal Storage',
    'flowchart.loopLimit': 'Loop Limit',
    'flowchart.manualInput': 'Manual Input',
    'flowchart.manualOperation': 'Manual Operation',
    'flowchart.mergeOrStorage': 'Merge or Storage',
    'flowchart.multiDocument': 'Multi-Document',
    'flowchart.offPageReference': 'Off-page Reference',
    'flowchart.onPageReference': 'On-page Reference',
    'flowchart.or': 'Or',
    'flowchart.paperTape': 'Paper Tape',
    'flowchart.parallelMode': 'Parallel Mode',
    'flowchart.predefinedProcess': 'Predefined Process',
    'flowchart.preparation': 'Preparation',
    'flowchart.process': 'Process',
    'flowchart.sequentialData': 'Sequential Data',
    'flowchart.sort': 'Sort',
    'flowchart.start1': 'Start 1',
    'flowchart.start2': 'Start 2',
    'flowchart.storedData': 'Stored Data',
    'flowchart.summingFunction': 'Summing Function',
    'flowchart.terminator': 'Terminator',
    'flowchart.transfer': 'Transfer',
  };
}
