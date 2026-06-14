// Generated from drawio/src/main/webapp/stencils/arrows.xml.
// Keep XML close to the upstream stencil definitions for easier future refreshes.

class ArrowStencils {
  const ArrowStencils._();

  static const List<String> xmlDefinitions = <String>[
    // Arrow Down
    r'''

<shape aspect="variable" h="97.5" name="arrows.arrowDown" strokewidth="inherit" w="70">
    <connections>
        <constraint name="N" perimeter="0" x="0.5" y="0" />
        <constraint name="S" perimeter="0" x="0.5" y="1" />
    </connections>
    <background>
        <path>
            <move x="20" y="0" />
            <line x="20" y="59" />
            <line x="0" y="59" />
            <line x="35" y="97.5" />
            <line x="70" y="59" />
            <line x="50" y="59" />
            <line x="50" y="0" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Arrow Left
    r'''

<shape aspect="variable" h="70" name="arrows.arrowLeft" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="97.5" y="20" />
            <line x="38.5" y="20" />
            <line x="38.5" y="0" />
            <line x="0" y="35" />
            <line x="38.5" y="70" />
            <line x="38.5" y="50" />
            <line x="97.5" y="50" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Arrow Right
    r'''

<shape aspect="variable" h="70" name="arrows.arrowRight" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
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
    // Arrow Up
    r'''

<shape aspect="variable" h="97.5" name="arrows.arrowUp" strokewidth="inherit" w="70">
    <connections>
        <constraint name="N" perimeter="0" x="0.5" y="0" />
        <constraint name="S" perimeter="0" x="0.5" y="1" />
    </connections>
    <background>
        <path>
            <move x="20" y="97.5" />
            <line x="20" y="38.5" />
            <line x="0" y="38.5" />
            <line x="35" y="0" />
            <line x="70" y="38.5" />
            <line x="50" y="38.5" />
            <line x="50" y="97.5" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Bent Left Arrow
    r'''

<shape aspect="variable" h="97" name="arrows.bentLeftArrow" strokewidth="inherit" w="97.01">
    <connections>
        <constraint name="S" perimeter="0" x="0.85" y="1" />
        <constraint name="W" perimeter="0" x="0" y="0.29" />
    </connections>
    <background>
        <path>
            <move x="68" y="97" />
            <line x="68" y="48" />
            <arc large-arc-flag="0" rx="5" ry="5" sweep-flag="0" x="63" x-axis-rotation="0" y="43" />
            <line x="38" y="43" />
            <line x="38" y="56" />
            <line x="0" y="28" />
            <line x="38" y="0" />
            <line x="38" y="13" />
            <line x="63" y="13" />
            <arc large-arc-flag="0" rx="35" ry="35" sweep-flag="1" x="97" x-axis-rotation="0" y="48" />
            <line x="97" y="97" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Bent Right Arrow
    r'''

<shape aspect="variable" h="97" name="arrows.bentRightArrow" strokewidth="inherit" w="97.01">
    <connections>
        <constraint name="S" perimeter="0" x="0.15" y="1" />
        <constraint name="E" perimeter="0" x="1" y="0.29" />
    </connections>
    <background>
        <path>
            <move x="29.01" y="97" />
            <line x="29.01" y="48" />
            <arc large-arc-flag="0" rx="5" ry="5" sweep-flag="1" x="34.01" x-axis-rotation="0" y="43" />
            <line x="59.01" y="43" />
            <line x="59.01" y="56" />
            <line x="97.01" y="28" />
            <line x="59.01" y="0" />
            <line x="59.01" y="13" />
            <line x="34.01" y="13" />
            <arc large-arc-flag="0" rx="35" ry="35" sweep-flag="0" x="0.01" x-axis-rotation="0" y="48" />
            <line x="0.01" y="97" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Bent Up Arrow
    r'''

<shape aspect="variable" h="83.5" name="arrows.bentUpArrow" strokewidth="inherit" w="97">
    <connections>
        <constraint name="N" perimeter="0" x="0.71" y="0" />
        <constraint name="W" perimeter="0" x="0" y="0.82" />
    </connections>
    <background>
        <path>
            <move x="0" y="53.5" />
            <line x="54" y="53.5" />
            <line x="54" y="23.5" />
            <line x="42" y="23.5" />
            <line x="69" y="0" />
            <line x="97" y="23.5" />
            <line x="84" y="23.5" />
            <line x="84" y="83.5" />
            <line x="0" y="83.5" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Callout Double Arrow
    r'''

<shape aspect="variable" h="97.5" name="arrows.calloutDoubleArrow" strokewidth="inherit" w="50">
    <connections>
        <constraint name="N" perimeter="0" x="0.5" y="0" />
        <constraint name="S" perimeter="0" x="0.5" y="1" />
    </connections>
    <background>
        <path>
            <move x="15" y="24" />
            <line x="15" y="19" />
            <line x="6" y="19" />
            <line x="25" y="0" />
            <line x="44" y="19" />
            <line x="35" y="19" />
            <line x="35" y="24" />
            <line x="50" y="24" />
            <line x="50" y="74" />
            <line x="35" y="74" />
            <line x="35" y="79" />
            <line x="44" y="79" />
            <line x="25" y="97.5" />
            <line x="6" y="79" />
            <line x="15" y="79" />
            <line x="15" y="74" />
            <line x="0" y="74" />
            <line x="0" y="24" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Callout Quad Arrow
    r'''

<shape aspect="variable" h="97" name="arrows.calloutQuadArrow" strokewidth="inherit" w="97">
    <connections>
        <constraint name="N" perimeter="0" x="0.5" y="0" />
        <constraint name="S" perimeter="0" x="0.5" y="1" />
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="38.5" y="23.5" />
            <line x="38.5" y="18.5" />
            <line x="29.5" y="18.5" />
            <line x="48.5" y="0" />
            <line x="67.5" y="18.5" />
            <line x="58.5" y="18.5" />
            <line x="58.5" y="23.5" />
            <line x="73.5" y="23.5" />
            <line x="73.5" y="38.5" />
            <line x="78.5" y="38.5" />
            <line x="78.5" y="29.5" />
            <line x="97" y="48.5" />
            <line x="78.5" y="67.5" />
            <line x="78.5" y="58.5" />
            <line x="73.5" y="58.5" />
            <line x="73.5" y="73.5" />
            <line x="58.5" y="73.5" />
            <line x="58.5" y="78.5" />
            <line x="67.5" y="78.5" />
            <line x="48.5" y="97" />
            <line x="29.5" y="78.5" />
            <line x="38.5" y="78.5" />
            <line x="38.5" y="73.5" />
            <line x="23.5" y="73.5" />
            <line x="23.5" y="58.5" />
            <line x="18.5" y="58.5" />
            <line x="18.5" y="67.5" />
            <line x="0" y="48.5" />
            <line x="18.5" y="29.5" />
            <line x="18.5" y="38.5" />
            <line x="23.5" y="38.5" />
            <line x="23.5" y="23.5" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Callout Up Arrow
    r'''

<shape aspect="variable" h="98" name="arrows.calloutUpArrow" strokewidth="inherit" w="60">
    <connections>
        <constraint name="N" perimeter="0" x="0.5" y="0" />
    </connections>
    <background>
        <path>
            <move x="20" y="39" />
            <line x="20" y="19" />
            <line x="11" y="19" />
            <line x="30" y="0" />
            <line x="49" y="19" />
            <line x="40" y="19" />
            <line x="40" y="39" />
            <line x="60" y="39" />
            <line x="60" y="98" />
            <line x="0" y="98" />
            <line x="0" y="39" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Chevron Arrow
    r'''

<shape aspect="variable" h="60" name="arrows.chevronArrow" strokewidth="inherit" w="96">
    <connections>
        <constraint name="W" perimeter="0" x="0.31" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="30" y="30" />
            <line x="0" y="0" />
            <line x="66" y="0" />
            <line x="96" y="30" />
            <line x="66" y="60" />
            <line x="0" y="60" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Circular Arrow
    r'''

<shape aspect="variable" h="69.5" name="arrows.circularArrow" strokewidth="inherit" w="97">
    <connections>
        <constraint name="SW" perimeter="0" x="0.12" y="0.64" />
        <constraint name="SE" perimeter="0" x="0.794" y="1" />
    </connections>
    <background>
        <path>
            <move x="0" y="44.5" />
            <arc large-arc-flag="0" rx="44.5" ry="44.5" sweep-flag="1" x="89" x-axis-rotation="0" y="44.5" />
            <line x="97" y="44.5" />
            <line x="77" y="69.5" />
            <line x="57" y="44.5" />
            <line x="65" y="44.5" />
            <arc large-arc-flag="0" rx="20.5" ry="20.5" sweep-flag="0" x="24" x-axis-rotation="0" y="44.5" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Jump-in Arrow 1
    r'''

<shape aspect="variable" h="99.41" name="arrows.jumpInArrow1" strokewidth="inherit" w="96">
    <connections>
        <constraint name="NW" perimeter="0" x="0" y="0.024" />
        <constraint name="S" perimeter="0" x="0.657" y="1" />
    </connections>
    <background>
        <path>
            <move x="30" y="60.41" />
            <line x="48" y="60.41" />
            <arc large-arc-flag="0" rx="60" ry="60" sweep-flag="0" x="0" x-axis-rotation="0" y="2.41" />
            <arc large-arc-flag="0" rx="75" ry="75" sweep-flag="1" x="78" x-axis-rotation="0" y="60.41" />
            <line x="96" y="60.41" />
            <line x="63" y="99.41" />
            <close />
        </path>
    </background>
    <foreground>
        <linejoin join="round" />
        <fillstroke />
    </foreground>
</shape>

''',
    // Jump-in Arrow 2
    r'''

<shape aspect="variable" h="99.41" name="arrows.jumpInArrow2" strokewidth="inherit" w="96">
    <connections>
        <constraint name="NE" perimeter="0" x="1" y="0.024" />
        <constraint name="S" perimeter="0" x="0.343" y="1" />
    </connections>
    <background>
        <path>
            <move x="66" y="60.41" />
            <line x="48" y="60.41" />
            <arc large-arc-flag="0" rx="60" ry="60" sweep-flag="1" x="96" x-axis-rotation="0" y="2.41" />
            <arc large-arc-flag="0" rx="75" ry="75" sweep-flag="0" x="18" x-axis-rotation="0" y="60.41" />
            <line x="0" y="60.41" />
            <line x="33" y="99.41" />
            <close />
        </path>
    </background>
    <foreground>
        <linejoin join="round" />
        <fillstroke />
    </foreground>
</shape>

''',
    // Left and Up Arrow
    r'''

<shape aspect="variable" h="96.5" name="arrows.leftAndUpArrow" strokewidth="inherit" w="96.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.71" />
        <constraint name="N" perimeter="0" x="0.71" y="0" />
    </connections>
    <background>
        <path>
            <move x="23.5" y="53.5" />
            <line x="53.5" y="53.5" />
            <line x="53.5" y="23.5" />
            <line x="41.5" y="23.5" />
            <line x="68.5" y="0" />
            <line x="96.5" y="23.5" />
            <line x="83.5" y="23.5" />
            <line x="83.5" y="83.5" />
            <line x="23.5" y="83.5" />
            <line x="23.5" y="96.5" />
            <line x="0" y="68.5" />
            <line x="23.5" y="41.5" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Left Sharp Edged Head Arrow
    r'''

<shape aspect="variable" h="60" name="arrows.leftSharpEdgedHeadArrow" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="97.5" y="20" />
            <line x="18.5" y="20" />
            <line x="30.5" y="0" />
            <line x="18.5" y="0" />
            <line x="0" y="30" />
            <line x="18.5" y="60" />
            <line x="30.5" y="60" />
            <line x="18.5" y="40" />
            <line x="97.5" y="40" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Notched Signal-in Arrow
    r'''

<shape aspect="variable" h="30" name="arrows.notchedSignalInArrow" strokewidth="inherit" w="96.5">
    <connections>
        <constraint name="W" perimeter="0" x="0.13" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="0" y="0" />
            <line x="83" y="0" />
            <line x="96.5" y="15" />
            <line x="83" y="30" />
            <line x="0" y="30" />
            <line x="13" y="15" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Quad Arrow
    r'''

<shape aspect="variable" h="97.5" name="arrows.quadArrow" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="N" perimeter="0" x="0.5" y="0" />
        <constraint name="S" perimeter="0" x="0.5" y="1" />
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="39" y="39" />
            <line x="39" y="19" />
            <line x="30" y="19" />
            <line x="49" y="0" />
            <line x="68" y="19" />
            <line x="59" y="19" />
            <line x="59" y="39" />
            <line x="79" y="39" />
            <line x="79" y="30" />
            <line x="97.5" y="49" />
            <line x="79" y="68" />
            <line x="79" y="59" />
            <line x="59" y="59" />
            <line x="59" y="79" />
            <line x="68" y="79" />
            <line x="49" y="97.5" />
            <line x="30" y="79" />
            <line x="39" y="79" />
            <line x="39" y="59" />
            <line x="19" y="59" />
            <line x="19" y="68" />
            <line x="0" y="49" />
            <line x="19" y="30" />
            <line x="19" y="39" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Right Notched Arrow
    r'''

<shape aspect="variable" h="70" name="arrows.rightNotchedArrow" strokewidth="inherit" w="96.5">
    <connections>
        <constraint name="W" perimeter="0" x="0.13" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="0" y="20" />
            <line x="58" y="20" />
            <line x="58" y="0" />
            <line x="96.5" y="35" />
            <line x="58" y="70" />
            <line x="58" y="50" />
            <line x="0" y="50" />
            <line x="13" y="35" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Sharp Edged Arrow
    r'''

<shape aspect="variable" h="60" name="arrows.sharpEdgedArrow" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="97.5" y="20" />
            <line x="18.5" y="20" />
            <line x="27.5" y="5" />
            <line x="18.5" y="0" />
            <line x="0" y="30" />
            <line x="18.5" y="60" />
            <line x="27.5" y="55" />
            <line x="18.5" y="40" />
            <line x="97.5" y="40" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Signal-in Arrow
    r'''

<shape aspect="variable" h="30" name="arrows.signalInArrow" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="0" y="0" />
            <line x="84" y="0" />
            <line x="97.5" y="15" />
            <line x="84" y="30" />
            <line x="0" y="30" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Slender Left Arrow
    r'''

<shape aspect="variable" h="60" name="arrows.slenderLeftArrow" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="97.5" y="20" />
            <line x="18.5" y="20" />
            <line x="18.5" y="0" />
            <line x="0" y="30" />
            <line x="18.5" y="60" />
            <line x="18.5" y="40" />
            <line x="97.5" y="40" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Slender Two Way Arrow
    r'''

<shape aspect="variable" h="60" name="arrows.slenderTwoWayArrow" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="78.5" y="20" />
            <line x="18.5" y="20" />
            <line x="18.5" y="0" />
            <line x="0" y="30" />
            <line x="18.5" y="60" />
            <line x="18.5" y="40" />
            <line x="78.5" y="40" />
            <line x="78.5" y="60" />
            <line x="97.5" y="30" />
            <line x="78.5" y="0" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Slender Wide Tailed Arrow
    r'''

<shape aspect="variable" h="60" name="arrows.slenderWideTailedArrow" strokewidth="inherit" w="96.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="0.8" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="58.5" y="20" />
            <line x="18.5" y="20" />
            <line x="18.5" y="0" />
            <line x="0" y="30" />
            <line x="18.5" y="60" />
            <line x="18.5" y="40" />
            <line x="58.5" y="40" />
            <line x="73.5" y="60" />
            <line x="96.5" y="60" />
            <line x="76.5" y="30" />
            <line x="96.5" y="0" />
            <line x="73.5" y="0" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Striped Arrow
    r'''

<shape aspect="variable" h="70" name="arrows.stripedArrow" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="24" y="20" />
            <line x="59" y="20" />
            <line x="59" y="0" />
            <line x="97.5" y="35" />
            <line x="59" y="70" />
            <line x="59" y="50" />
            <line x="24" y="50" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
        <rect h="30" w="12" x="8" y="20" />
        <fillstroke />
        <rect h="30" w="4" x="0" y="20" />
        <fillstroke />
    </foreground>
</shape>

''',
    // Stylised Notched Arrow
    r'''

<shape aspect="variable" h="60" name="arrows.stylisedNotchedArrow" strokewidth="inherit" w="96.5">
    <connections>
        <constraint name="W" perimeter="0" x="0.13" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="0" y="5" />
            <line x="68" y="20" />
            <line x="58" y="0" />
            <line x="96.5" y="30" />
            <line x="58" y="60" />
            <line x="68" y="45" />
            <line x="0" y="55" />
            <line x="13" y="30" />
            <close />
        </path>
    </background>
    <foreground>
        <miterlimit limit="8" />
        <fillstroke />
    </foreground>
</shape>

''',
    // Triad Arrow
    r'''

<shape aspect="variable" h="68" name="arrows.triadArrow" strokewidth="inherit" w="97.5">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.72" />
        <constraint name="E" perimeter="0" x="1" y="0.72" />
        <constraint name="N" perimeter="0" x="0.5" y="0" />
    </connections>
    <background>
        <path>
            <move x="39" y="39" />
            <line x="39" y="19" />
            <line x="30" y="19" />
            <line x="49" y="0" />
            <line x="68" y="19" />
            <line x="59" y="19" />
            <line x="59" y="39" />
            <line x="79" y="39" />
            <line x="79" y="30" />
            <line x="97.5" y="49" />
            <line x="79" y="68" />
            <line x="79" y="59" />
            <line x="39" y="59" />
            <line x="19" y="59" />
            <line x="19" y="68" />
            <line x="0" y="49" />
            <line x="19" y="30" />
            <line x="19" y="39" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Two Way Arrow Horizontal
    r'''

<shape aspect="variable" h="60" name="arrows.twoWayArrowHorizontal" strokewidth="inherit" w="96">
    <connections>
        <constraint name="W" perimeter="0" x="0" y="0.5" />
        <constraint name="E" perimeter="0" x="1" y="0.5" />
    </connections>
    <background>
        <path>
            <move x="63" y="15" />
            <line x="63" y="0" />
            <line x="96" y="30" />
            <line x="63" y="60" />
            <line x="63" y="45" />
            <line x="33" y="45" />
            <line x="33" y="60" />
            <line x="0" y="30" />
            <line x="33" y="0" />
            <line x="33" y="15" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // Two Way Arrow Vertical
    r'''

<shape aspect="variable" h="96" name="arrows.twoWayArrowVertical" strokewidth="inherit" w="60">
    <connections>
        <constraint name="N" perimeter="0" x="0.5" y="0" />
        <constraint name="S" perimeter="0" x="0.5" y="1" />
    </connections>
    <background>
        <path>
            <move x="15" y="63" />
            <line x="0" y="63" />
            <line x="30" y="96" />
            <line x="60" y="63" />
            <line x="45" y="63" />
            <line x="45" y="33" />
            <line x="60" y="33" />
            <line x="30" y="0" />
            <line x="0" y="33" />
            <line x="15" y="33" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // U Turn Arrow
    r'''

<shape aspect="variable" h="98" name="arrows.uTurnArrow" strokewidth="inherit" w="97">
    <connections>
        <constraint name="SW" perimeter="0" x="0.12" y="1" />
        <constraint name="SE" perimeter="0" x="0.792" y="0.71" />
    </connections>
    <background>
        <path>
            <move x="0" y="44.5" />
            <arc large-arc-flag="0" rx="44.5" ry="44.5" sweep-flag="1" x="89" x-axis-rotation="0" y="44.5" />
            <line x="97" y="44.5" />
            <line x="77" y="69.5" />
            <line x="57" y="44.5" />
            <line x="65" y="44.5" />
            <arc large-arc-flag="0" rx="20.5" ry="20.5" sweep-flag="0" x="24" x-axis-rotation="0" y="44.83" />
            <line x="24" y="98" />
            <line x="0" y="98" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // U Turn Down Arrow
    r'''

<shape aspect="variable" h="62" name="arrows.uTurnDownArrow" strokewidth="inherit" w="97">
    <connections>
        <constraint name="SE" perimeter="0" x="0.91" y="1" />
        <constraint name="SW" perimeter="0" x="0.237" y="1" />
    </connections>
    <background>
        <path>
            <move x="97" y="62" />
            <line x="97" y="32" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="0" x="33" x-axis-rotation="0" y="32" />
            <line x="46" y="32" />
            <line x="23" y="62" />
            <line x="0" y="32" />
            <line x="13" y="32" />
            <arc large-arc-flag="0" rx="32" ry="32" sweep-flag="1" x="45" x-axis-rotation="0" y="0" />
            <line x="65" y="0" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="0" x="53" x-axis-rotation="0" y="3" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="1" x="78" x-axis-rotation="0" y="32" />
            <line x="78" y="62" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // U Turn Left Arrow
    r'''

<shape aspect="variable" h="97" name="arrows.uTurnLeftArrow" strokewidth="inherit" w="62">
    <connections>
        <constraint name="SW" perimeter="0" x="0" y="0.76" />
        <constraint name="NW" perimeter="0" x="0" y="0.1" />
    </connections>
    <background>
        <path>
            <move x="0" y="0" />
            <line x="30" y="0" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="1" x="30" x-axis-rotation="0" y="64" />
            <line x="30" y="51" />
            <line x="0" y="74" />
            <line x="30" y="97" />
            <line x="30" y="84" />
            <arc large-arc-flag="0" rx="32" ry="32" sweep-flag="0" x="62" x-axis-rotation="0" y="52" />
            <line x="62" y="32" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="1" x="59" x-axis-rotation="0" y="44" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="0" x="30" x-axis-rotation="0" y="19" />
            <line x="0" y="19" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // U Turn Right Arrow
    r'''

<shape aspect="variable" h="97" name="arrows.uTurnRightArrow" strokewidth="inherit" w="62">
    <connections>
        <constraint name="SW" perimeter="0" x="1" y="0.76" />
        <constraint name="NW" perimeter="0" x="1" y="0.1" />
    </connections>
    <background>
        <path>
            <move x="62" y="0" />
            <line x="32" y="0" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="0" x="32" x-axis-rotation="0" y="64" />
            <line x="32" y="51" />
            <line x="62" y="74" />
            <line x="32" y="97" />
            <line x="32" y="84" />
            <arc large-arc-flag="0" rx="32" ry="32" sweep-flag="1" x="0" x-axis-rotation="0" y="52" />
            <line x="0" y="32" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="0" x="3" x-axis-rotation="0" y="44" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="1" x="32" x-axis-rotation="0" y="19" />
            <line x="62" y="19" />
            <close />
        </path>
    </background>
    <foreground>
        <fillstroke />
    </foreground>
</shape>

''',
    // U Turn Up Arrow
    r'''

<shape aspect="variable" h="62" name="arrows.uTurnUpArrow" strokewidth="inherit" w="97">
    <connections>
        <constraint name="NE" perimeter="0" x="0.91" y="0" />
        <constraint name="NW" perimeter="0" x="0.237" y="0" />
    </connections>
    <background>
        <path>
            <move x="97" y="0" />
            <line x="97" y="30" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="1" x="33" x-axis-rotation="0" y="30" />
            <line x="46" y="30" />
            <line x="23" y="0" />
            <line x="0" y="30" />
            <line x="13" y="30" />
            <arc large-arc-flag="0" rx="32" ry="32" sweep-flag="0" x="45" x-axis-rotation="0" y="62" />
            <line x="65" y="62" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="1" x="53" x-axis-rotation="0" y="59" />
            <arc large-arc-flag="0" rx="30" ry="30" sweep-flag="0" x="78" x-axis-rotation="0" y="30" />
            <line x="78" y="0" />
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
    'arrows.arrowDown': <String>[
      'mxgraph.arrows.arrowDown',
      'mxgraph.arrows.arrow_down',
      'mxgraph.arrows.arrow-down',
      'mxgraph.arrows.Arrow Down',
    ],
    'arrows.arrowLeft': <String>[
      'mxgraph.arrows.arrowLeft',
      'mxgraph.arrows.arrow_left',
      'mxgraph.arrows.arrow-left',
      'mxgraph.arrows.Arrow Left',
    ],
    'arrows.arrowRight': <String>[
      'mxgraph.arrows.arrowRight',
      'mxgraph.arrows.arrow_right',
      'mxgraph.arrows.arrow-right',
      'mxgraph.arrows.Arrow Right',
    ],
    'arrows.arrowUp': <String>[
      'mxgraph.arrows.arrowUp',
      'mxgraph.arrows.arrow_up',
      'mxgraph.arrows.arrow-up',
      'mxgraph.arrows.Arrow Up',
    ],
    'arrows.bentLeftArrow': <String>[
      'mxgraph.arrows.bentLeftArrow',
      'mxgraph.arrows.bent_left_arrow',
      'mxgraph.arrows.bent-left-arrow',
      'mxgraph.arrows.Bent Left Arrow',
    ],
    'arrows.bentRightArrow': <String>[
      'mxgraph.arrows.bentRightArrow',
      'mxgraph.arrows.bent_right_arrow',
      'mxgraph.arrows.bent-right-arrow',
      'mxgraph.arrows.Bent Right Arrow',
    ],
    'arrows.bentUpArrow': <String>[
      'mxgraph.arrows.bentUpArrow',
      'mxgraph.arrows.bent_up_arrow',
      'mxgraph.arrows.bent-up-arrow',
      'mxgraph.arrows.Bent Up Arrow',
    ],
    'arrows.calloutDoubleArrow': <String>[
      'mxgraph.arrows.calloutDoubleArrow',
      'mxgraph.arrows.callout_double_arrow',
      'mxgraph.arrows.callout-double-arrow',
      'mxgraph.arrows.Callout Double Arrow',
    ],
    'arrows.calloutQuadArrow': <String>[
      'mxgraph.arrows.calloutQuadArrow',
      'mxgraph.arrows.callout_quad_arrow',
      'mxgraph.arrows.callout-quad-arrow',
      'mxgraph.arrows.Callout Quad Arrow',
    ],
    'arrows.calloutUpArrow': <String>[
      'mxgraph.arrows.calloutUpArrow',
      'mxgraph.arrows.callout_up_arrow',
      'mxgraph.arrows.callout-up-arrow',
      'mxgraph.arrows.Callout Up Arrow',
    ],
    'arrows.chevronArrow': <String>[
      'mxgraph.arrows.chevronArrow',
      'mxgraph.arrows.chevron_arrow',
      'mxgraph.arrows.chevron-arrow',
      'mxgraph.arrows.Chevron Arrow',
    ],
    'arrows.circularArrow': <String>[
      'mxgraph.arrows.circularArrow',
      'mxgraph.arrows.circular_arrow',
      'mxgraph.arrows.circular-arrow',
      'mxgraph.arrows.Circular Arrow',
    ],
    'arrows.jumpInArrow1': <String>[
      'mxgraph.arrows.jumpInArrow1',
      'mxgraph.arrows.jump_in_arrow_1',
      'mxgraph.arrows.jump-in-arrow-1',
      'mxgraph.arrows.Jump-in Arrow 1',
    ],
    'arrows.jumpInArrow2': <String>[
      'mxgraph.arrows.jumpInArrow2',
      'mxgraph.arrows.jump_in_arrow_2',
      'mxgraph.arrows.jump-in-arrow-2',
      'mxgraph.arrows.Jump-in Arrow 2',
    ],
    'arrows.leftAndUpArrow': <String>[
      'mxgraph.arrows.leftAndUpArrow',
      'mxgraph.arrows.left_and_up_arrow',
      'mxgraph.arrows.left-and-up-arrow',
      'mxgraph.arrows.Left and Up Arrow',
    ],
    'arrows.leftSharpEdgedHeadArrow': <String>[
      'mxgraph.arrows.leftSharpEdgedHeadArrow',
      'mxgraph.arrows.left_sharp_edged_head_arrow',
      'mxgraph.arrows.left-sharp-edged-head-arrow',
      'mxgraph.arrows.Left Sharp Edged Head Arrow',
    ],
    'arrows.notchedSignalInArrow': <String>[
      'mxgraph.arrows.notchedSignalInArrow',
      'mxgraph.arrows.notched_signal_in_arrow',
      'mxgraph.arrows.notched-signal-in-arrow',
      'mxgraph.arrows.Notched Signal-in Arrow',
    ],
    'arrows.quadArrow': <String>[
      'mxgraph.arrows.quadArrow',
      'mxgraph.arrows.quad_arrow',
      'mxgraph.arrows.quad-arrow',
      'mxgraph.arrows.Quad Arrow',
    ],
    'arrows.rightNotchedArrow': <String>[
      'mxgraph.arrows.rightNotchedArrow',
      'mxgraph.arrows.right_notched_arrow',
      'mxgraph.arrows.right-notched-arrow',
      'mxgraph.arrows.Right Notched Arrow',
    ],
    'arrows.sharpEdgedArrow': <String>[
      'mxgraph.arrows.sharpEdgedArrow',
      'mxgraph.arrows.sharp_edged_arrow',
      'mxgraph.arrows.sharp-edged-arrow',
      'mxgraph.arrows.Sharp Edged Arrow',
    ],
    'arrows.signalInArrow': <String>[
      'mxgraph.arrows.signalInArrow',
      'mxgraph.arrows.signal_in_arrow',
      'mxgraph.arrows.signal-in-arrow',
      'mxgraph.arrows.Signal-in Arrow',
    ],
    'arrows.slenderLeftArrow': <String>[
      'mxgraph.arrows.slenderLeftArrow',
      'mxgraph.arrows.slender_left_arrow',
      'mxgraph.arrows.slender-left-arrow',
      'mxgraph.arrows.Slender Left Arrow',
    ],
    'arrows.slenderTwoWayArrow': <String>[
      'mxgraph.arrows.slenderTwoWayArrow',
      'mxgraph.arrows.slender_two_way_arrow',
      'mxgraph.arrows.slender-two-way-arrow',
      'mxgraph.arrows.Slender Two Way Arrow',
    ],
    'arrows.slenderWideTailedArrow': <String>[
      'mxgraph.arrows.slenderWideTailedArrow',
      'mxgraph.arrows.slender_wide_tailed_arrow',
      'mxgraph.arrows.slender-wide-tailed-arrow',
      'mxgraph.arrows.Slender Wide Tailed Arrow',
    ],
    'arrows.stripedArrow': <String>[
      'mxgraph.arrows.stripedArrow',
      'mxgraph.arrows.striped_arrow',
      'mxgraph.arrows.striped-arrow',
      'mxgraph.arrows.Striped Arrow',
    ],
    'arrows.stylisedNotchedArrow': <String>[
      'mxgraph.arrows.stylisedNotchedArrow',
      'mxgraph.arrows.stylised_notched_arrow',
      'mxgraph.arrows.stylised-notched-arrow',
      'mxgraph.arrows.Stylised Notched Arrow',
    ],
    'arrows.triadArrow': <String>[
      'mxgraph.arrows.triadArrow',
      'mxgraph.arrows.triad_arrow',
      'mxgraph.arrows.triad-arrow',
      'mxgraph.arrows.Triad Arrow',
    ],
    'arrows.twoWayArrowHorizontal': <String>[
      'mxgraph.arrows.twoWayArrowHorizontal',
      'mxgraph.arrows.two_way_arrow_horizontal',
      'mxgraph.arrows.two-way-arrow-horizontal',
      'mxgraph.arrows.Two Way Arrow Horizontal',
    ],
    'arrows.twoWayArrowVertical': <String>[
      'mxgraph.arrows.twoWayArrowVertical',
      'mxgraph.arrows.two_way_arrow_vertical',
      'mxgraph.arrows.two-way-arrow-vertical',
      'mxgraph.arrows.Two Way Arrow Vertical',
    ],
    'arrows.uTurnArrow': <String>[
      'mxgraph.arrows.uTurnArrow',
      'mxgraph.arrows.u_turn_arrow',
      'mxgraph.arrows.u-turn-arrow',
      'mxgraph.arrows.U Turn Arrow',
    ],
    'arrows.uTurnDownArrow': <String>[
      'mxgraph.arrows.uTurnDownArrow',
      'mxgraph.arrows.u_turn_down_arrow',
      'mxgraph.arrows.u-turn-down-arrow',
      'mxgraph.arrows.U Turn Down Arrow',
    ],
    'arrows.uTurnLeftArrow': <String>[
      'mxgraph.arrows.uTurnLeftArrow',
      'mxgraph.arrows.u_turn_left_arrow',
      'mxgraph.arrows.u-turn-left-arrow',
      'mxgraph.arrows.U Turn Left Arrow',
    ],
    'arrows.uTurnRightArrow': <String>[
      'mxgraph.arrows.uTurnRightArrow',
      'mxgraph.arrows.u_turn_right_arrow',
      'mxgraph.arrows.u-turn-right-arrow',
      'mxgraph.arrows.U Turn Right Arrow',
    ],
    'arrows.uTurnUpArrow': <String>[
      'mxgraph.arrows.uTurnUpArrow',
      'mxgraph.arrows.u_turn_up_arrow',
      'mxgraph.arrows.u-turn-up-arrow',
      'mxgraph.arrows.U Turn Up Arrow',
    ],
  };

  static const List<String> keys = <String>[
    'arrows.arrowDown',
    'arrows.arrowLeft',
    'arrows.arrowRight',
    'arrows.arrowUp',
    'arrows.bentLeftArrow',
    'arrows.bentRightArrow',
    'arrows.bentUpArrow',
    'arrows.calloutDoubleArrow',
    'arrows.calloutQuadArrow',
    'arrows.calloutUpArrow',
    'arrows.chevronArrow',
    'arrows.circularArrow',
    'arrows.jumpInArrow1',
    'arrows.jumpInArrow2',
    'arrows.leftAndUpArrow',
    'arrows.leftSharpEdgedHeadArrow',
    'arrows.notchedSignalInArrow',
    'arrows.quadArrow',
    'arrows.rightNotchedArrow',
    'arrows.sharpEdgedArrow',
    'arrows.signalInArrow',
    'arrows.slenderLeftArrow',
    'arrows.slenderTwoWayArrow',
    'arrows.slenderWideTailedArrow',
    'arrows.stripedArrow',
    'arrows.stylisedNotchedArrow',
    'arrows.triadArrow',
    'arrows.twoWayArrowHorizontal',
    'arrows.twoWayArrowVertical',
    'arrows.uTurnArrow',
    'arrows.uTurnDownArrow',
    'arrows.uTurnLeftArrow',
    'arrows.uTurnRightArrow',
    'arrows.uTurnUpArrow',
  ];

  static const Map<String, String> labels = <String, String>{
    'arrows.arrowDown': '向下箭头',
    'arrows.arrowLeft': '向左箭头',
    'arrows.arrowRight': '向右箭头',
    'arrows.arrowUp': '向上箭头',
    'arrows.bentLeftArrow': '折弯左箭头',
    'arrows.bentRightArrow': '折弯右箭头',
    'arrows.bentUpArrow': '折弯上箭头',
    'arrows.calloutDoubleArrow': '标注双向箭头',
    'arrows.calloutQuadArrow': '标注四向箭头',
    'arrows.calloutUpArrow': '标注上箭头',
    'arrows.chevronArrow': 'V形箭头',
    'arrows.circularArrow': '环形箭头',
    'arrows.jumpInArrow1': '跳入箭头1',
    'arrows.jumpInArrow2': '跳入箭头2',
    'arrows.leftAndUpArrow': '左上箭头',
    'arrows.leftSharpEdgedHeadArrow': '左尖头箭头',
    'arrows.notchedSignalInArrow': '缺口信号箭头',
    'arrows.quadArrow': '四向箭头',
    'arrows.rightNotchedArrow': '右缺口箭头',
    'arrows.sharpEdgedArrow': '尖边箭头',
    'arrows.signalInArrow': '信号箭头',
    'arrows.slenderLeftArrow': '细长左箭头',
    'arrows.slenderTwoWayArrow': '细长双向箭头',
    'arrows.slenderWideTailedArrow': '细长宽尾箭头',
    'arrows.stripedArrow': '条纹箭头',
    'arrows.stylisedNotchedArrow': '风格化缺口箭头',
    'arrows.triadArrow': '三向箭头',
    'arrows.twoWayArrowHorizontal': '水平双向箭头',
    'arrows.twoWayArrowVertical': '垂直双向箭头',
    'arrows.uTurnArrow': 'U形转弯箭头',
    'arrows.uTurnDownArrow': 'U形向下箭头',
    'arrows.uTurnLeftArrow': 'U形向左箭头',
    'arrows.uTurnRightArrow': 'U形向右箭头',
    'arrows.uTurnUpArrow': 'U形向上箭头',
  };
}
