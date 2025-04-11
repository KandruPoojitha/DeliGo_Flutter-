import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleOrderDialog extends StatefulWidget {
  final String restaurantName;
  final Function(DateTime) onSchedule;

  const ScheduleOrderDialog({
    super.key,
    required this.restaurantName,
    required this.onSchedule,
  });

  @override
  State<ScheduleOrderDialog> createState() => _ScheduleOrderDialogState();
}

class _ScheduleOrderDialogState extends State<ScheduleOrderDialog> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule,
              size: 48,
              color: Color(0xFFF4A261),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.restaurantName} is currently closed',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Would you like to schedule your order for later?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Select Date'),
              subtitle: Text(
                DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                style: const TextStyle(color: Color(0xFFF4A261)),
              ),
              onTap: () => _selectDate(context),
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Select Time'),
              subtitle: Text(
                _selectedTime.format(context),
                style: const TextStyle(color: Color(0xFFF4A261)),
              ),
              onTap: () => _selectTime(context),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    widget.onSchedule(scheduledDateTime);
                    Navigator.pop(context);
                  },
                  child: const Text('Schedule Order'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 