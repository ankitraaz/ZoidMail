// lib/widgets/home_page_widget.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Make sure you have 'intl' in your pubspec.yaml

// ====================================================================
// EmailItemModel: Data model for individual emails
// ====================================================================
class EmailItemModel {
  final String id;
  final String name;
  final String title;
  final String body;
  final String avatar;
  final Color color;
  final DateTime receivedAt;
  bool isRead;

  EmailItemModel({
    required this.id,
    required this.name,
    required this.title,
    required this.body,
    required this.avatar,
    required this.color,
    required this.receivedAt,
    this.isRead = false,
  });
}

// ====================================================================
// HeroSection: Displays current email and actions (Updated for editable field)
// ====================================================================
class HeroSection extends StatefulWidget {
  final String currentEmail;
  final ValueChanged<String> onEmailChanged; // Callback when email is typed
  final VoidCallback onGenerateNew;
  final VoidCallback onCopyEmail;
  final VoidCallback onShowQrCode; // New callback for QR button

  const HeroSection({
    Key? key,
    required this.currentEmail,
    required this.onEmailChanged,
    required this.onGenerateNew,
    required this.onCopyEmail,
    required this.onShowQrCode,
  }) : super(key: key);

  @override
  _HeroSectionState createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  late TextEditingController _emailController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.currentEmail);
  }

  @override
  void didUpdateWidget(covariant HeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text if the currentEmail changes externally (e.g., new email generated)
    if (widget.currentEmail != oldWidget.currentEmail && !_isEditing) {
      _emailController.text = widget.currentEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inbox in Seconds Gone in Minutes', // New Title
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Temporary, encrypted, and always in your control. Zoid Mail is your first line of defense in a world filled with digital clutter.', // New Subtitle
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Email Display/Editable Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _isEditing
                      ? TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter your custom email...',
                          ),
                          onSubmitted: (value) {
                            setState(() {
                              _isEditing = false;
                            });
                            widget.onEmailChanged(
                                value); // Notify parent of change
                          },
                          keyboardType: TextInputType.emailAddress,
                          autofocus: true,
                        )
                      : Text(
                          widget.currentEmail.isEmpty
                              ? '123abc@edu.com'
                              : widget.currentEmail,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: widget.currentEmail.isEmpty
                                ? Colors.grey
                                : Colors.blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                IconButton(
                  icon: Icon(_isEditing ? Icons.check : Icons.edit,
                      color: Colors.blue),
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                      if (!_isEditing) {
                        widget.onEmailChanged(
                            _emailController.text); // Save on toggle off
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // QR Code and Copy Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onShowQrCode,
                  icon: const Icon(Icons.qr_code,
                      color: Colors.blue), // Updated icon for QR
                  label: const Text('QR Code',
                      style: TextStyle(color: Colors.blue)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.white, // White background for QR button
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onCopyEmail,
                  icon: const Icon(Icons.copy, color: Colors.white),
                  label:
                      const Text('Copy', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
              height: 16), // Space between buttons and generate new email
          // Generate New Email Button (Still useful if they want to discard custom)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onGenerateNew,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate New Email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// InboxSection: Displays the list of emails
// (No changes needed here unless you want to update card styles or list item details)
// ====================================================================
class InboxSection extends StatelessWidget {
  final List<EmailItemModel> emails;
  final AsyncCallback onRefresh;
  final Function(String emailId) onEmailTap;
  final Function(String emailId) onEmailDelete;

  const InboxSection({
    Key? key,
    required this.emails,
    required this.onRefresh,
    required this.onEmailTap,
    required this.onEmailDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Inbox', // Changed title to 'Inbox' as per design
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh,
                  color: Colors.grey), // Refresh icon as per design
              onPressed: onRefresh,
              tooltip: 'Refresh Inbox',
            ),
          ],
        ),
        const SizedBox(height: 16),
        emails.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No emails yet.',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your temporary inbox is waiting!',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: emails.length,
                itemBuilder: (context, index) {
                  final email = emails[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: email.isRead ? 0.5 : 2,
                    color: email.isRead ? Colors.white : Colors.blue[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        onEmailTap(email.id);
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: email.color,
                                    child: Text(
                                      email.avatar,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      email.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              content: SingleChildScrollView(
                                child: ListBody(
                                  children: <Widget>[
                                    const SizedBox(height: 8),
                                    Text(
                                      email.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Received: ${DateFormat('MMM dd, hh:mm a').format(email.receivedAt)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const Divider(),
                                    Text(
                                      email.body,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    onEmailDelete(email.id);
                                  },
                                ),
                                TextButton(
                                  child: const Text('Close'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: email.color,
                              child: Text(
                                email.avatar,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email.name,
                                    style: TextStyle(
                                      fontWeight: email.isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    email.title,
                                    style: TextStyle(
                                      fontWeight: email.isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    email.body,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('hh:mm a').format(email.receivedAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}

// ====================================================================
// HowToUseSection: Explains how to use the app (Updated for numbered circles)
// ====================================================================
class HowToUseSection extends StatelessWidget {
  const HowToUseSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How to use temporary Email', // Updated title
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildStep(
          context,
          stepNumber: 1,
          description: 'Copy temporary email address', // Updated text
        ),
        _buildStep(
          context,
          stepNumber: 2,
          description:
              'Use it to sign up on websites, socials.', // Updated text
        ),
        _buildStep(
          context,
          stepNumber: 3,
          description: 'Read incoming emails on this page', // Updated text
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context,
      {required int stepNumber, required String description}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Align vertically
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue, // Blue circle
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800]), // Slightly larger text
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// WhatIsTemporaryEmailSection: Explains temporary emails (No changes)
// ====================================================================
class WhatIsTemporaryEmailSection extends StatelessWidget {
  const WhatIsTemporaryEmailSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What is a Temporary Email?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'A temporary email is a disposable email address that you can use instead of your real one for various online activities. It helps protect your privacy, reduce spam, and avoid unwanted newsletters from websites you only visit once.',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        SizedBox(height: 10),
        Text(
          'Zoid Mail provides you with a short-lived email address that automatically deletes after a set period. All emails sent to this address will appear in your temporary inbox.',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
      ],
    );
  }
}

// ====================================================================
// AppExtensionsSection: Placeholder for app extensions info (No changes)
// ====================================================================
class AppExtensionsSection extends StatelessWidget {
  const AppExtensionsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App & Extensions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: [
            _buildExtensionChip(icon: Icons.android, label: 'Android App'),
            _buildExtensionChip(icon: Icons.apple, label: 'iOS App'),
            _buildExtensionChip(icon: Icons.web, label: 'Web Extension'),
            _buildExtensionChip(icon: Icons.language, label: 'Other Platforms'),
          ],
        ),
      ],
    );
  }

  Widget _buildExtensionChip({required IconData icon, required String label}) {
    return Chip(
      avatar: Icon(icon, color: Colors.blue),
      label: Text(label),
      backgroundColor: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
