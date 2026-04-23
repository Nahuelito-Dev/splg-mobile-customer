import 'package:flutter/material.dart';

class TimeRangeSelector extends StatelessWidget {
  final List<int> availableStartHours;
  final List<int> availableEndHours;
  final int? selectedStartHour;
  final int? selectedEndHour;
  final ValueChanged<int?> onStartHourChanged;
  final ValueChanged<int?> onEndHourChanged;

  const TimeRangeSelector({
    super.key,
    required this.availableStartHours,
    required this.availableEndHours,
    required this.selectedStartHour,
    required this.selectedEndHour,
    required this.onStartHourChanged,
    required this.onEndHourChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿En qué horario la podés recibir?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                context,
                label: 'Desde',
                value: selectedStartHour,
                items: availableStartHours,
                onChanged: onStartHourChanged,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown(
                context,
                label: 'Hasta',
                value: selectedEndHour,
                items: availableEndHours,
                onChanged: onEndHourChanged,
                disabled: selectedStartHour == null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    required int? value,
    required List<int> items,
    required ValueChanged<int?> onChanged,
    bool disabled = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: disabled
                ? theme.colorScheme.onSurface.withAlpha(20)
                : theme.colorScheme.surfaceContainerHighest.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withAlpha(50),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              hint: Text(disabled ? '-' : 'Seleccionar'),
              items: items.map((hour) {
                return DropdownMenuItem<int>(
                  value: hour,
                  child: Text('$hour:00'),
                );
              }).toList(),
              onChanged: disabled ? null : onChanged,
              icon: Icon(
                Icons.access_time,
                color:
                    disabled ? theme.disabledColor : theme.colorScheme.primary,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
