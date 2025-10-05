import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A customizable date picker component that displays a popup dialog
/// for selecting dates.
class DatePopupPicker extends StatefulWidget {
  /// The initial date to display in the picker
  final DateTime? initialDate;
  
  /// The earliest date that can be selected
  final DateTime? firstDate;
  
  /// The latest date that can be selected
  final DateTime? lastDate;
  
  /// The format to display the selected date
  final String? dateFormat;
  
  /// Callback when a date is selected
  final Function(DateTime) onDateSelected;
  
  /// Placeholder text when no date is selected
  final String hintText;
  
  /// Custom decoration for the field
  final InputDecoration? decoration;
  
  /// Whether the field is enabled
  final bool enabled;
  
  /// Custom icon for the date picker button
  final IconData? icon;
  
  /// Custom style for the displayed date text
  final TextStyle? textStyle;
  
  /// Custom builder for rendering the date picker widget
  /// If provided, this will override the default TextField implementation
  final Widget Function(BuildContext context, VoidCallback onTap, String? displayText, bool isEnabled)? builder;

  const DatePopupPicker({
    super.key,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.dateFormat,
    required this.onDateSelected,
    this.hintText = 'select date',
    this.decoration,
    this.enabled = true,
    this.icon,
    this.textStyle,
    this.builder,
  });

  @override
  State<DatePopupPicker> createState() => _DatePopupPickerState();
}

class _DatePopupPickerState extends State<DatePopupPicker> {
  DateTime? _selectedDate;
  late TextEditingController _controller;
  String? _displayText;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _controller = TextEditingController();
    _updateControllerText();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DatePopupPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDate != widget.initialDate) {
      _selectedDate = widget.initialDate;
      _updateControllerText();
    }
  }

  void _updateControllerText() {
    if (_selectedDate != null) {
      final format = widget.dateFormat ?? 'yyyy-MM-dd';
      _displayText = DateFormat(format).format(_selectedDate!);
      _controller.text = _displayText!;
    } else {
      _displayText = null;
      _controller.text = '';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = widget.firstDate ?? DateTime(now.year - 100, 1, 1);
    final DateTime lastDate = widget.lastDate ?? DateTime(now.year + 100, 12, 31);
    final DateTime initialDate = _selectedDate ?? now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(firstDate) && initialDate.isBefore(lastDate) 
          ? initialDate 
          : now,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateControllerText();
      });
      widget.onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If a custom builder is provided, use it
    if (widget.builder != null) {
      return widget.builder!(
        context, 
        widget.enabled ? () => _selectDate(context) : () {}, 
        _displayText, 
        widget.enabled
      );
    }
    
    // Otherwise use the default TextField implementation
    final InputDecoration effectiveDecoration = widget.decoration ??
        InputDecoration(
          hintText: widget.hintText,
          suffixIcon: Icon(widget.icon ?? Icons.calendar_today),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        );

    return TextField(
      controller: _controller,
      decoration: effectiveDecoration,
      readOnly: true,
      enabled: widget.enabled,
      style: widget.textStyle,
      onTap: widget.enabled ? () => _selectDate(context) : null,
    );
  }
}

/// A simplified version of DatePopupPicker that displays a button
/// which opens a date picker when pressed
class DatePickerButton extends StatelessWidget {
  /// The initial date to display in the picker
  final DateTime? initialDate;
  
  /// The earliest date that can be selected
  final DateTime? firstDate;
  
  /// The latest date that can be selected
  final DateTime? lastDate;
  
  /// Callback when a date is selected
  final Function(DateTime) onDateSelected;
  
  /// Text to display on the button
  final String buttonText;
  
  /// Icon to display on the button
  final IconData icon;
  
  /// Custom style for the button
  final ButtonStyle? buttonStyle;
  
  /// Custom builder for the button
  final Widget Function(BuildContext context, VoidCallback onTap)? buttonBuilder;

  const DatePickerButton({
    super.key,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    required this.onDateSelected,
    this.buttonText = '选择日期',
    this.icon = Icons.calendar_today,
    this.buttonStyle,
    this.buttonBuilder,
  });

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = this.firstDate ?? DateTime(now.year - 100, 1, 1);
    final DateTime lastDate = this.lastDate ?? DateTime(now.year + 100, 12, 31);
    final DateTime initialDate = this.initialDate ?? now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(firstDate) && initialDate.isBefore(lastDate) 
          ? initialDate 
          : now,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If a custom button builder is provided, use it
    if (buttonBuilder != null) {
      return buttonBuilder!(context, () => _selectDate(context));
    }
    
    // Otherwise use the default button implementation
    return ElevatedButton.icon(
      onPressed: () => _selectDate(context),
      icon: Icon(icon),
      label: Text(buttonText),
      style: buttonStyle ?? 
        ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
    );
  }
}

/// A range date picker that allows selecting a start and end date
class DateRangePicker extends StatefulWidget {
  /// The initial start date
  final DateTime? initialStartDate;
  
  /// The initial end date
  final DateTime? initialEndDate;
  
  /// The earliest date that can be selected
  final DateTime? firstDate;
  
  /// The latest date that can be selected
  final DateTime? lastDate;
  
  /// The format to display dates
  final String dateFormat;
  
  /// Callback when date range is selected
  final Function(DateTime, DateTime) onDateRangeSelected;
  
  /// Text for the start date field
  final String startHintText;
  
  /// Text for the end date field
  final String endHintText;
  
  /// Custom builder for the start date field
  final Widget Function(BuildContext context, VoidCallback onTap, String? displayText, bool isEnabled)? startDateBuilder;
  
  /// Custom builder for the end date field
  final Widget Function(BuildContext context, VoidCallback onTap, String? displayText, bool isEnabled)? endDateBuilder;

  const DateRangePicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.firstDate,
    this.lastDate,
    this.dateFormat = 'yyyy-MM-dd',
    required this.onDateRangeSelected,
    this.startHintText = '开始日期',
    this.endHintText = '结束日期',
    this.startDateBuilder,
    this.endDateBuilder,
  });

  @override
  State<DateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<DateRangePicker> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  void didUpdateWidget(DateRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStartDate != widget.initialStartDate) {
      _startDate = widget.initialStartDate;
    }
    if (oldWidget.initialEndDate != widget.initialEndDate) {
      _endDate = widget.initialEndDate;
    }
  }

  void _onStartDateSelected(DateTime date) {
    setState(() {
      _startDate = date;
      // If end date is before start date, update end date
      if (_endDate != null && _endDate!.isBefore(date)) {
        _endDate = date;
      }
    });
    
    if (_endDate != null) {
      widget.onDateRangeSelected(_startDate!, _endDate!);
    }
  }

  void _onEndDateSelected(DateTime date) {
    setState(() {
      _endDate = date;
      // If start date is after end date, update start date
      if (_startDate != null && _startDate!.isAfter(date)) {
        _startDate = date;
      }
    });
    
    if (_startDate != null) {
      widget.onDateRangeSelected(_startDate!, _endDate!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DatePopupPicker(
            initialDate: _startDate,
            firstDate: widget.firstDate,
            lastDate: _endDate ?? widget.lastDate,
            dateFormat: widget.dateFormat,
            onDateSelected: _onStartDateSelected,
            hintText: widget.startHintText,
            builder: widget.startDateBuilder,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DatePopupPicker(
            initialDate: _endDate,
            firstDate: _startDate ?? widget.firstDate,
            lastDate: widget.lastDate,
            dateFormat: widget.dateFormat,
            onDateSelected: _onEndDateSelected,
            hintText: widget.endHintText,
            builder: widget.endDateBuilder,
          ),
        ),
      ],
    );
  }
}
