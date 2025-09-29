
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthPickerWidget extends StatelessWidget {
  final Function(String) onMonthSelected;

  const MonthPickerWidget({super.key, required this.onMonthSelected});

  @override
  Widget build(BuildContext context) {
    final currentDate = DateTime.now();
    final months = _generateMonths(currentDate);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Month',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Month list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                final isCurrentMonth = month['key'] == DateFormat('yyyy-MM').format(currentDate);
                
                return ListTile(
                  leading: Icon(
                    isCurrentMonth ? Icons.today : Icons.calendar_month,
                    color: isCurrentMonth ? Colors.green : Colors.white70,
                  ),
                  title: Text(
                    month['display']!,
                    style: TextStyle(
                      color: isCurrentMonth ? Colors.green : Colors.white,
                      fontWeight: isCurrentMonth ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: isCurrentMonth 
                      ? const Text(
                          'Current Month',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        )
                      : null,
                  onTap: () => onMonthSelected(month['key']!),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Map<String, String>> _generateMonths(DateTime currentDate) {
    final months = <Map<String, String>>[];
    
    // Add last 12 months
    for (int i = 0; i >= -11; i--) {
      final date = DateTime(currentDate.year, currentDate.month + i, 1);
      months.add({
        'key': DateFormat('yyyy-MM').format(date),
        'display': DateFormat('MMMM yyyy').format(date),
      });
    }
    
    return months;
  }
}