import 'package:flutter/material.dart';

import '../../theme/ui_colors.dart';

class SearchBox extends StatelessWidget {
  const SearchBox({this.onChanged});

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: UiColors.text),
        decoration: InputDecoration(
          hintText: '搜索图形',
          hintStyle: const TextStyle(color: Color(0xFF8795A3)),
          prefixIcon: const Icon(
            Icons.search,
            size: 16,
            color: Color(0xFF7D8C99),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          isDense: true,
          filled: true,
          fillColor: UiColors.panelSoft,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: UiColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: UiColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF9FC4E8)),
          ),
        ),
      ),
    );
  }
}
