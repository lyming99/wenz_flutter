import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class DocFormulaNode extends StatefulWidget {
  final String? formula;
  final double width;
  final double height;

  const DocFormulaNode({
    super.key,
    this.formula,
    required this.width,
    required this.height,
  });

  @override
  State<DocFormulaNode> createState() => _DocFormulaNodeState();
}

class _DocFormulaNodeState extends State<DocFormulaNode> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          Math.tex(
            widget.formula ?? "",
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
