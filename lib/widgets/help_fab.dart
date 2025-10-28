import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpFab extends StatelessWidget {
  final String? url;
  
  const HelpFab({
    super.key,
    this.url,
  });

  // Default help URL - can change this to desired webpage
  static const String defaultHelpUrl = 'https://kingmatazu.github.io/';

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _openHelpPage(context),
      backgroundColor: Colors.amber,
      heroTag: 'help_fab', // Unique tag to avoid hero animation conflicts
      child: const Icon(
        Icons.lightbulb_outline,
        color: Colors.white,
      ),
    );
  }

  Future<void> _openHelpPage(BuildContext context) async {
    final urlToOpen = url ?? defaultHelpUrl;
    final uri = Uri.parse(urlToOpen);

    try {
      // Check if the URL can be launched
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Opens in default browser
        );
      } else {
        if (context.mounted) {
          _showErrorDialog(context, 'Could not open the help page.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Error opening help page: $e');
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Error',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
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
}