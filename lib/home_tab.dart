import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import 'package:zoidmail/widgets/home_page_widget.dart';

class HomeTabScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const HomeTabScreen({
    Key? key,
    required this.firestore,
    required this.auth,
  }) : super(key: key);

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive =>
      true; // Crucial for IndexedStack to keep state alive

  String _currentEmail = "";
  bool _isLoading = true;
  List<EmailItemModel> _emails = []; // EmailItemModel is now recognized
  StreamSubscription<QuerySnapshot>? _emailSubscription;

  @override
  void initState() {
    super.initState();
    _initializeUserAndLoadData();
  }

  @override
  void dispose() {
    _emailSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeUserAndLoadData() async {
    print('[HomeTabScreen] Starting initialization...');
    setState(() {
      _isLoading = true;
    });
    try {
      if (widget.auth.currentUser == null) {
        print(
            '[HomeTabScreen] Current user is null, signing in anonymously...');
        await widget.auth.signInAnonymously();
        print(
            '[HomeTabScreen] Signed in anonymously. User ID: ${widget.auth.currentUser?.uid}');
      } else {
        print(
            '[HomeTabScreen] User already signed in. User ID: ${widget.auth.currentUser?.uid}');
      }

      print('[HomeTabScreen] Loading current email...');
      await _loadCurrentEmail();
      print('[HomeTabScreen] Current email loaded: $_currentEmail');

      print('[HomeTabScreen] Setting up email listener...');
      _setupEmailListener();
      print('[HomeTabScreen] Email listener setup complete.');
    } catch (e) {
      print('[HomeTabScreen] ERROR during initialization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initialization error: ${e.toString()}')),
        );
      }
    } finally {
      print(
          '[HomeTabScreen] Finally block reached. Setting _isLoading to false.');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('[HomeTabScreen] _isLoading set to false.');
      } else {
        print(
            '[HomeTabScreen] Widget not mounted, cannot set _isLoading to false.');
      }
    }
  }

  Future<void> _loadCurrentEmail() async {
    try {
      final user = widget.auth.currentUser;
      if (user == null) {
        setState(() {
          _currentEmail = "N/A";
          _emails = [];
        });
        return;
      }

      final doc =
          await widget.firestore.collection('temp_emails').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();

        if (DateTime.now().isBefore(expiresAt) && data['isActive'] == true) {
          setState(() {
            _currentEmail = data['email'];
          });
        } else {
          // If expired or inactive, generate a new one
          await _generateNewEmail();
        }
      } else {
        // No existing email, generate one
        await _generateNewEmail();
      }
    } catch (e) {
      print('Error loading current email: $e');
      // Fallback to generating new email on error
      await _generateNewEmail();
    }
  }

  Future<void> _generateNewEmail() async {
    try {
      final user = widget.auth.currentUser;
      if (user == null) return;

      final newEmail = _createRandomEmail();
      final expiryTime = DateTime.now().add(const Duration(minutes: 10));

      await widget.firestore.collection('temp_emails').doc(user.uid).set({
        'email': newEmail,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiryTime),
        'isActive': true,
      });

      if (mounted) {
        setState(() {
          _currentEmail = newEmail;
          _emails = []; // Clear old emails when generating new address
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New temporary email generated!')),
        );
      }
      _setupEmailListener(); // Restart listener for the new email
    } catch (e) {
      print('Error generating new email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating email: ${e.toString()}')),
        );
      }
    }
  }

  // --- NEW: Handle user-typed email ---
  Future<void> _handleCustomEmail(String customEmail) async {
    // Basic validation for an email-like string
    if (!customEmail.contains('@') || !customEmail.contains('.')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email format.')),
        );
      }
      // Revert to current generated email if invalid or do nothing
      if (mounted) {
        setState(() {
          _currentEmail =
              _currentEmail; // This line forces a refresh if _currentEmail is unchanged but the TextField was changed
        });
      }
      return;
    }

    try {
      final user = widget.auth.currentUser;
      if (user == null) return;

      // Placeholder for actual Firestore update for custom email
      // In a real app, you'd check availability server-side or via a Cloud Function
      await widget.firestore.collection('temp_emails').doc(user.uid).set(
          {
            'email': customEmail,
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(
                minutes: 60))), // Give custom email longer expiry
            'isActive': true,
            'isCustom': true, // New field to denote custom email
          },
          SetOptions(
              merge: true)); // Use merge to avoid overwriting other fields

      if (mounted) {
        setState(() {
          _currentEmail = customEmail;
          _emails = []; // Clear inbox for the new custom email
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom email set!')),
        );
      }
      _setupEmailListener(); // Restart listener for the new custom email
    } catch (e) {
      print('Error setting custom email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error setting custom email: ${e.toString()}')),
        );
      }
    }
  }

  // --- NEW: Show QR Code Dialog ---
  void _showQrCodeDialog() {
    if (_currentEmail.isEmpty || _currentEmail == "N/A") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Generate an email first to get a QR code!')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Your Email QR Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // You'll need a QR code generator package here, e.g., 'qr_flutter'
              // Example using placeholder:
              Container(
                width: 200,
                height: 200,
                color: Colors.blueGrey[100],
                child: Center(
                  child: Text('QR Code for\n$_currentEmail',
                      textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                _currentEmail,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: _copyEmail, // Use the existing copy function
              child: const Text('Copy Email'),
            ),
          ],
        );
      },
    );
  }

  String _createRandomEmail() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final randomString = String.fromCharCodes(
      Iterable.generate(
          8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    return '$randomString@zoidmail.com';
  }

  Future<void> _copyEmail() async {
    if (_currentEmail.isNotEmpty && _currentEmail != "N/A") {
      await Clipboard.setData(ClipboardData(text: _currentEmail));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email copied to clipboard!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No email to copy!')),
        );
      }
    }
  }

  void _setupEmailListener() {
    final user = widget.auth.currentUser;
    print('[EmailListener] Current User: ${user?.uid}');
    print('[EmailListener] Current Email being listened for: $_currentEmail');

    if (user == null || _currentEmail.isEmpty || _currentEmail == "N/A") {
      _emailSubscription?.cancel();
      if (mounted) {
        setState(() {
          _emails = [];
        });
      }
      print(
          '[EmailListener] User or Current Email is empty, listener cancelled/not started.');
      return;
    }

    _emailSubscription?.cancel(); // Cancel previous subscription

    _emailSubscription = widget.firestore
        .collection('emails')
        .where('tempEmail', isEqualTo: _currentEmail)
        .where('userId', isEqualTo: user.uid)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      print('[EmailListener] Listener received an update!');
      print(
          '[EmailListener] Number of documents in snapshot: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print(
            '[EmailListener] Snapshot is empty. No emails found for $_currentEmail and ${user.uid}');
      } else {
        print(
            '[EmailListener] First email subject in snapshot: ${snapshot.docs.first.data()['subject']}');
      }

      final emailList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return EmailItemModel(
          id: doc.id,
          name: data['senderName'] ?? 'Unknown',
          title: data['subject'] ?? 'No Subject',
          body: data['body'] ?? '',
          avatar: (data['senderName']?.isNotEmpty == true
                  ? data['senderName'][0]
                  : 'U')
              .toString()
              .toUpperCase(),
          color: _getRandomColor(),
          receivedAt:
              (data['receivedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isRead: data['isRead'] ?? false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _emails = emailList;
        });
        print(
            '[EmailListener] _emails updated via setState. Current emails count: ${_emails.length}');
      }
    }, onError: (error) {
      print('[EmailListener] ERROR listening to emails: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading emails: ${error.toString()}')),
        );
      }
    });
  }

  Color _getRandomColor() {
    final colors = [
      Colors.purple,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[Random().nextInt(colors.length)];
  }

  Future<void> _refreshInbox() async {
    setState(() {
      _isLoading = true;
    });
    // Re-load email to ensure it's still active or generate new if needed
    await _loadCurrentEmail();
    _setupEmailListener(); // Re-setup listener to ensure it's on the correct email
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inbox refreshed!')),
      );
    }
  }

  Future<void> _addTestEmail() async {
    print('[AddTestEmail] Attempting to add test email...');
    try {
      final user = widget.auth.currentUser;
      print('[AddTestEmail] User: ${user?.uid}, Current Email: $_currentEmail');

      if (user == null || _currentEmail.isEmpty || _currentEmail == "N/A") {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please wait for email to generate or sign in.')),
          );
        }
        print(
            '[AddTestEmail] User is null or currentEmail is empty. Aborting.');
        return;
      }

      final testEmails = [
        {
          'senderName': 'GitHub',
          'subject': 'Welcome to GitHub!',
          'body':
              'Thank you for joining GitHub. Get started with your first repository. This is a long body to test overflow.',
        },
        {
          'senderName': 'Netflix',
          'subject': 'Confirm your subscription',
          'body':
              'Please confirm your Netflix subscription to continue enjoying our service. Click here to confirm.',
        },
        {
          'senderName': 'Amazon',
          'subject': 'Your order has been shipped',
          'body':
              'Your recent Amazon order is on its way! Track your package here. Order #123456789.',
        },
      ];
      final randomEmailData = testEmails[Random().nextInt(testEmails.length)];

      await widget.firestore.collection('emails').add({
        'tempEmail': _currentEmail,
        'userId': user.uid,
        'senderName': randomEmailData['senderName'],
        'subject': randomEmailData['subject'],
        'body': randomEmailData['body'],
        'receivedAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('[AddTestEmail] Test email added to Firestore successfully!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test email added!')),
        );
      }
    } catch (e) {
      print('[AddTestEmail] ERROR adding test email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding test email: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _markEmailAsRead(String emailId) async {
    try {
      await widget.firestore.collection('emails').doc(emailId).update({
        'isRead': true,
      });
      // Update local list to reflect read status instantly
      if (mounted) {
        setState(() {
          final index = _emails.indexWhere((e) => e.id == emailId);
          if (index != -1) {
            _emails[index].isRead = true;
          }
        });
      }
    } catch (e) {
      print('Error marking email as read: $e');
    }
  }

  Future<void> _deleteEmail(String emailId) async {
    try {
      await widget.firestore.collection('emails').doc(emailId).delete();
      // Firestore listener will automatically update _emails list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email deleted!')),
        );
      }
    } catch (e) {
      print('Error deleting email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.mail, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Zoid Mail',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeroSection(
                      currentEmail: _currentEmail,
                      onEmailChanged:
                          _handleCustomEmail, // Pass the new handler
                      onGenerateNew: _generateNewEmail,
                      onCopyEmail: _copyEmail,
                      onShowQrCode:
                          _showQrCodeDialog, // Pass the new QR handler
                    ),
                    const SizedBox(height: 24),
                    InboxSection(
                      emails: _emails,
                      onRefresh: _refreshInbox,
                      onEmailTap: _markEmailAsRead,
                      onEmailDelete: _deleteEmail,
                    ),
                    const SizedBox(height: 32),
                    const HowToUseSection(),
                    const SizedBox(height: 32),
                    const WhatIsTemporaryEmailSection(),
                    const SizedBox(height: 32),
                    const AppExtensionsSection(),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Column(
                        children: [
                          const Text('Zoid Mail',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              )),
                          const SizedBox(height: 8),
                          const Text('© 2025 Zoid Mail. All rights reserved.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              )),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 16.0,
                            runSpacing: 8.0,
                            alignment: WrapAlignment.center,
                            children: const [
                              Text('Features',
                                  style: TextStyle(color: Colors.grey)),
                              Text('Signup Required',
                                  style: TextStyle(color: Colors.grey)),
                              Text('API Access',
                                  style: TextStyle(color: Colors.grey)),
                              Text('Instant Inbox Disposal',
                                  style: TextStyle(color: Colors.grey)),
                              Text('FAQ', style: TextStyle(color: Colors.grey)),
                              Text('Support',
                                  style: TextStyle(color: Colors.grey)),
                              Text('Privacy Policy',
                                  style: TextStyle(color: Colors.grey)),
                              Text('Terms of Service',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
