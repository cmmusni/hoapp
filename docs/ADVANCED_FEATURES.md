# Advanced Features Guide

This guide covers the newly implemented advanced features: PDF generation, file uploads, and realtime subscriptions.

## 📄 PDF Generation

### Overview
Generate professional PDF documents for invoices, waivers, and reports using the `PDFService`.

### Setup
The PDF service is available in `core_ui` package:

```dart
import 'package:core_ui/core_ui.dart';

final pdfService = PDFService();
```

### Generate Pool Access Waiver

```dart
// Generate waiver PDF
final pdfBytes = await pdfService.generatePoolAccessWaiver(
  community: community,
  registration: poolAccessRegistration,
  userName: 'John Doe',
);

// Preview/print the PDF
await pdfService.previewPDF(pdfBytes, 'pool_waiver.pdf');

// Share PDF (mobile)
await pdfService.sharePDF(pdfBytes, 'pool_waiver.pdf');

// Download PDF (web)
await pdfService.downloadPDF(pdfBytes, 'pool_waiver.pdf');
```

### Generate Invoice PDF

```dart
final pdfBytes = await pdfService.generateInvoicePDF(
  community: community,
  invoice: invoice,
  payments: paymentHistory, // optional
);

await pdfService.downloadPDF(pdfBytes, 'invoice_${invoice.id}.pdf');
```

### Example Integration in Pool Access Page

```dart
// In your pool access registration screen
ElevatedButton(
  onPressed: () async {
    final pdfService = PDFService();
    final pdfBytes = await pdfService.generatePoolAccessWaiver(
      community: appState.activeCommunity!,
      registration: registration,
      userName: appState.currentUser?.email,
    );
    
    // Show preview/print dialog
    await pdfService.previewPDF(pdfBytes, 'pool_waiver.pdf');
  },
  child: const Text('Download Waiver PDF'),
)
```

---

## 📤 File Uploads

### Overview
Upload files to Supabase Storage buckets with validation, progress tracking, and preview.

### Storage Buckets (Created via Migrations)

The following buckets are automatically created by database migrations:
- `violation-photos` - For violation reports (public)
- `pool-access-docs` - For signed pool waivers
- `payment-proofs` - For payment receipts (public)
- `community-logos` - For community branding (public)
- `announcement-attachments` - For announcement files (public)
- `expense-receipts` - For expense documentation (public)
- `feedback-images` - For feedback submission attachments

### Storage Service Usage

```dart
import 'package:core_data/core_data.dart';

final storageService = StorageService(getSupabaseClient());

// Pick and upload a file
final file = await storageService.pickFile(
  type: FileType.image,
  allowedExtensions: ['jpg', 'jpeg', 'png'],
);

if (file != null) {
  // Validate size (5MB max)
  if (storageService.validateFileSize(file, 5 * 1024 * 1024)) {
    final url = await storageService.uploadFile(
      bucket: 'violation-photos',
      file: file,
      folder: communityId, // optional folder
    );
    
    print('Uploaded to: $url');
  }
}
```

### Using FileUploadWidget

The easiest way to add file uploads to your UI:

```dart
import 'package:core_ui/core_ui.dart';

FileUploadWidget(
  bucket: 'violation-photos',
  folder: communityId,
  fileType: FileType.image,
  allowedExtensions: ['jpg', 'jpeg', 'png'],
  maxSizeBytes: 5 * 1024 * 1024, // 5MB
  onUploadComplete: (url) {
    print('File uploaded: $url');
    // Save URL to your model
  },
  initialUrl: existingPhotoUrl, // optional
)
```

### Using ImageUploadWidget

For simple image uploads with preview:

```dart
ImageUploadWidget(
  bucket: 'payment-proofs',
  folder: 'invoices/$invoiceId',
  onUploadComplete: (url) {
    setState(() {
      paymentProofUrl = url;
    });
  },
  initialUrl: payment.proofUrl,
)
```

### Example: Adding Photo Upload to Violations

```dart
// In _ReportViolationDialog
class _ReportViolationDialogState extends State<_ReportViolationDialog> {
  String? _photoUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Violation'),
      content: Column(
        children: [
          // ... existing form fields ...
          
          const SizedBox(height: 16),
          
          // Add photo upload
          FileUploadWidget(
            bucket: 'violation-photos',
            folder: appState.activeCommunityId,
            fileType: FileType.image,
            allowedExtensions: ['jpg', 'jpeg', 'png'],
            maxSizeBytes: 5 * 1024 * 1024,
            onUploadComplete: (url) {
              _photoUrl = url;
            },
          ),
        ],
      ),
      // ... rest of dialog ...
    );
  }
  
  Future<void> _submitReport() async {
    // Include photo URL in violation creation
    await repo.createViolation(
      violation.copyWith(photoUrl: _photoUrl),
    );
  }
}
```

### File Management Methods

```dart
final storageService = StorageService(getSupabaseClient());

// Download file
final bytes = await storageService.downloadFile(
  bucket: 'pool-documents',
  filePath: 'community123/waiver_123.pdf',
);

// Delete file
await storageService.deleteFile(
  bucket: 'violation-photos',
  filePath: 'community123/photo_456.jpg',
);

// Get public URL
final url = storageService.getPublicUrl(
  bucket: 'community-logos',
  filePath: 'logo.png',
);
```

---

## 🔴 Realtime Subscriptions

### Overview
Subscribe to database changes and receive live updates using Supabase Realtime.

### Setup RealtimeService

```dart
import 'package:core_data/core_data.dart';

final realtimeService = RealtimeService(getSupabaseClient());
```

### Subscribe to Announcements

```dart
// In your announcements page
String? _subscriptionKey;

@override
void initState() {
  super.initState();
  _loadAnnouncements();
  _subscribeToAnnouncements();
}

void _subscribeToAnnouncements() {
  final appState = context.read<AppState>();
  final realtimeService = context.read<RealtimeService>();
  
  _subscriptionKey = realtimeService.subscribeToAnnouncements(
    communityId: appState.activeCommunityId!,
    onNewAnnouncement: (data) {
      // New announcement received
      setState(() {
        _loadAnnouncements(); // Refresh list
      });
      
      // Show notification
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New announcement posted')),
      );
    },
  );
}

@override
void dispose() {
  if (_subscriptionKey != null) {
    context.read<RealtimeService>().unsubscribe(_subscriptionKey!);
  }
  super.dispose();
}
```

### Subscribe to Ticket Messages (Chat)

Perfect for real-time chat in tickets:

```dart
// In ticket detail page
void _subscribeToMessages() {
  _messageSubscription = realtimeService.subscribeToTicketMessages(
    ticketId: widget.ticket.id,
    onNewMessage: (messageData) {
      // Convert data to Message model
      final message = Message.fromJson(messageData);
      
      setState(() {
        _messages.add(message);
      });
      
      // Scroll to bottom
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    },
  );
}
```

### Subscribe to Violations

```dart
_subscriptionKey = realtimeService.subscribeToViolations(
  communityId: communityId,
  onViolationUpdate: (data) {
    // Violation created, updated, or deleted
    _loadViolations();
  },
);
```

### Subscribe to Invoices

Get notified when invoices are paid:

```dart
_subscriptionKey = realtimeService.subscribeToInvoices(
  communityId: communityId,
  onInvoiceUpdate: (data) {
    final invoice = Invoice.fromJson(data);
    
    if (invoice.paidAt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice #${invoice.id} has been paid'),
          backgroundColor: Colors.green,
        ),
      );
    }
    
    _loadInvoices();
  },
);
```

### Subscribe to Amenity Bookings

```dart
_subscriptionKey = realtimeService.subscribeToAmenityBookings(
  amenityId: amenityId,
  onNewBooking: (data) {
    final booking = AmenityBooking.fromJson(data);
    _loadBookings();
  },
);
```

### Custom Table Subscriptions

Subscribe to any table with custom filters:

```dart
_subscriptionKey = realtimeService.subscribeToTable(
  table: 'user_roles',
  event: 'INSERT', // or UPDATE, DELETE, or *
  filter: 'community_id=eq.$communityId',
  callback: (data) {
    print('New user role added: $data');
  },
);
```

### Presence Tracking

Track online users in a channel:

```dart
_presenceKey = realtimeService.subscribeToPresence(
  channelName: 'community_$communityId',
  onPresenceChange: (users) {
    setState(() {
      _onlineUsers = users;
    });
  },
);
```

### Broadcast Messages

Send ephemeral messages without database persistence:

```dart
// Subscribe to broadcasts
_broadcastKey = realtimeService.subscribeToBroadcast(
  channelName: 'notifications',
  event: 'new_alert',
  callback: (payload) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(payload['title']),
        content: Text(payload['message']),
      ),
    );
  },
);

// Send broadcast
await realtimeService.broadcast(
  channelKey: _broadcastKey,
  event: 'new_alert',
  payload: {
    'title': 'Emergency Alert',
    'message': 'Pool closed for maintenance',
  },
);
```

### Cleanup

Always unsubscribe when disposing:

```dart
@override
void dispose() {
  // Unsubscribe from specific channel
  if (_subscriptionKey != null) {
    realtimeService.unsubscribe(_subscriptionKey!);
  }
  
  // Or unsubscribe from all
  realtimeService.unsubscribeAll();
  
  super.dispose();
}
```

---

## 🎯 Complete Integration Example

### Enhanced Ticket Chat with Realtime

```dart
class _TicketDetailState extends State<_TicketDetail> {
  final _messageController = TextEditingController();
  List<Message> _messages = [];
  String? _messageSubscription;
  late RealtimeService _realtimeService;

  @override
  void initState() {
    super.initState();
    _realtimeService = context.read<RealtimeService>();
    _loadMessages();
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _messageSubscription = _realtimeService.subscribeToTicketMessages(
      ticketId: widget.ticket.id,
      onNewMessage: (data) {
        final message = Message.fromJson(data);
        setState(() {
          _messages.add(message);
        });
      },
    );
  }

  @override
  void dispose() {
    if (_messageSubscription != null) {
      _realtimeService.unsubscribe(_messageSubscription!);
    }
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... UI implementation with real-time updates
  }
}
```

---

## 🔧 Provider Setup

Add services to your Provider setup in `main.dart`:

```dart
MultiProvider(
  providers: [
    Provider(create: (_) => getSupabaseClient()),
    ProxyProvider<SupabaseClient, StorageService>(
      update: (_, client, __) => StorageService(client),
    ),
    ProxyProvider<SupabaseClient, RealtimeService>(
      update: (_, client, __) => RealtimeService(client),
    ),
    Provider(create: (_) => PDFService()),
    // ... other providers
  ],
  child: MyApp(),
)
```

---

## 📋 Storage Policies Required

Add these policies in Supabase Dashboard for each bucket:

```sql
-- Allow authenticated users to upload
CREATE POLICY "Users can upload files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'violation-photos');

-- Allow authenticated users to view
CREATE POLICY "Users can view files"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'violation-photos');

-- Staff can delete
CREATE POLICY "Staff can delete files"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'violation-photos' 
  AND is_community_staff(auth.uid(), (storage.foldername(name))[1]::uuid)
);
```

---

## 🚀 Next Steps

1. **Run migrations** to enable Realtime on tables:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE violations;
ALTER PUBLICATION supabase_realtime ADD TABLE invoices;
```

2. **Create storage buckets** in Supabase Dashboard

3. **Install dependencies**:
```bash
cd packages/core_data && flutter pub get
cd ../core_ui && flutter pub get
cd ../../apps/web_portal && flutter pub get
```

4. **Test features** in your screens

---

## 💡 Tips

- **File Size Limits**: Default is 5MB, adjust based on your needs
- **Storage Costs**: Monitor usage in Supabase Dashboard
- **Realtime Connections**: Each subscription uses a database connection
- **PDF Size**: Large PDFs may take time to generate on web
- **Image Optimization**: Consider compressing images before upload
