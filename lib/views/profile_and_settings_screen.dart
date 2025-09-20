
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/services/grocery_service.dart';
import 'package:grocery_glide/views/master_template_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileAndSettingsScreen extends ConsumerWidget {
  const ProfileAndSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D),
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Section
            _buildProfileSection(),
            const SizedBox(height: 32),
            
            // Settings Sections
            _buildSettingsSection(
              title: 'Template Management',
              items: [
                _SettingsItem(
                  icon: Icons.list_alt,
                  title: 'Manage Master Template',
                  subtitle: 'Edit your default grocery list',
                  onTap: () => _navigateToMasterTemplate(context),
                ),
                _SettingsItem(
                  icon: Icons.refresh,
                  title: 'Reset Current Month',
                  subtitle: 'Mark all items as unbought',
                  onTap: () => _resetCurrentMonth(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            _buildSettingsSection(
              title: 'Data Management',
              items: [
                _SettingsItem(
                  icon: Icons.analytics_outlined,
                  title: 'Shopping Statistics',
                  subtitle: 'View your shopping history',
                  onTap: () => _showStatistics(context),
                ),
                _SettingsItem(
                  icon: Icons.backup,
                  title: 'Export Data',
                  subtitle: 'Export your grocery data',
                  onTap: () => _exportData(context),
                ),
                _SettingsItem(
                  icon: Icons.delete_forever,
                  title: 'Clear All Data',
                  subtitle: 'Delete all grocery data',
                  textColor: Colors.red,
                  onTap: () => _clearAllData(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            _buildSettingsSection(
              title: 'App Settings',
              items: [
                _SettingsItem(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: 'Shopping reminders',
                  onTap: () => _showNotificationSettings(context),
                ),
                _SettingsItem(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'App version and info',
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Grocery Shopper',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Managing your grocery lists',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<_SettingsItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: items.map((item) => _buildSettingsItem(item)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(_SettingsItem item) {
    return ListTile(
      leading: Icon(
        item.icon,
        color: item.textColor ?? Colors.white.withValues(alpha: 0.8),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          color: item.textColor ?? Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: item.subtitle != null
          ? Text(
              item.subtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Colors.white.withValues(alpha: 0.4),
        size: 16,
      ),
      onTap: item.onTap,
    );
  }

  void _navigateToMasterTemplate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MasterTemplateScreen()),
    );
  }

  void _resetCurrentMonth(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('Reset Current Month', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will mark all items in the current month as unbought. Continue?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await GroceryService.resetAllItemsToUnbought();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current month reset successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting month: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showStatistics(BuildContext context) {
    // Placeholder for statistics screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Statistics feature coming soon!')),
    );
  }

  void _exportData(BuildContext context) {
    // Placeholder for export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon!')),
    );
  }

  void _clearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('Clear All Data', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete all your grocery data including templates and history. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await GroceryService.deleteAllItems();
        // Also clear the first-time setup flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('first_time_setup_complete');
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Pop back to main screen
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Notification settings will be available in a future update.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Grocery Glide',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.shopping_cart, color: Colors.white, size: 30),
      ),
      children: [
        const Text('A simple and efficient grocery list manager.'),
        const SizedBox(height: 16),
        const Text('Features:'),
        const Text('• Master template management'),
        const Text('• Monthly grocery lists'),
        const Text('• Shopping progress tracking'),
        const Text('• Search and filter capabilities'),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? textColor;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.textColor,
    required this.onTap,
  });
}