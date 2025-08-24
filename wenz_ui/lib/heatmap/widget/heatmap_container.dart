import 'package:flutter/material.dart';
import '../data/heatmap_color.dart';

class HeatMapContainer extends StatelessWidget {
  final DateTime date;
  final double? size;
  final double? fontSize;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? textColor;
  final EdgeInsets? margin;
  final bool? showText;
  final Function(DateTime dateTime)? onClick;
  final DateTime? selectDate;

  const HeatMapContainer({
    Key? key,
    required this.date,
    this.margin,
    this.size,
    this.fontSize,
    this.borderRadius,
    this.backgroundColor,
    this.selectedColor,
    this.textColor,
    this.onClick,
    this.showText,
    this.selectDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.all(2),
      child: MouseRegion(
        cursor: onClick != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.none,
        child: GestureDetector(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: selectedColor ?? backgroundColor,
              borderRadius:
                  BorderRadius.all(Radius.circular(borderRadius ?? 5)),
              border: selectDate == date
                  ? Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                      width: 2)
                  : Border.all(
                      color: Colors.transparent, width: 0),
            ),
            clipBehavior: Clip.hardEdge,
            child: (showText ?? true)
                ? Text(
                    date.day.toString(),
                    style: TextStyle(
                        color: textColor ?? const Color(0xFF8A8A8A),
                        fontSize: fontSize),
                  )
                : null,
          ),
          onTap: () {
            onClick != null ? onClick!(date) : null;
          },
        ),
      ),
    );
  }
}
