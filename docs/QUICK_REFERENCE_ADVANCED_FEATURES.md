# Quick Reference: Advanced Features

## 📄 PDF Generation

```dart
// Generate pool waiver
final pdf = await PDFService().generatePoolAccessWaiver(
  community: community,
  registration: registration,
  userName: userName,
);
await PDFService().previewPDF(pdf, 'waiver.pdf');

// Generate invoice
final pdf = await PDFService().generateInvoicePDF(
  community: community,
  invoice: invoice,
  payments: payments,
);
await PDFService().sharePDF(pdf, 'invoice.pdf');
```

---

## 📤 File Uploads

```dart
// Quick image upload with widget
ImageUploadWidget(
  bucket: 'violation-photos',
  onUploadComplete: (url) => setState(() => photoUrl = url),
)

// Full file upload with validation
FileUploadWidget(
  bucket: 'payment-proofs',
  folder: communityId,
  fileType: FileType.image,
  allowedExtensions: ['jpg', 'png', 'pdf'],
  maxSizeBytes: 5 * 1024 * 1024, // 5MB
  onUploadComplete: (url) => print('Uploaded: $url'),
)

// Manual upload with StorageService
final service = StorageService(getSupabaseClient());
final file = await service.pickImage();
if (file != null) {
  final url = await service.uploadImage(
    bucket: 'photos',
    file: file,
    folder: 'community/$communityId',
  );
}
```

---

## 🔴 Realtime Subscriptions

```dart
// Subscribe to table changes
final key = realtimeService.subscribeToTable(
  table: 'announcements',
  event: 'INSERT',
  filter: 'community_id=eq.$communityId',
  callback: (data) => print('New announcement: $data'),
);

// Specialized subscriptions
final key = realtimeService.subscribeToTicketMessages(
  ticketId: ticketId,
  onNewMessage: (data) {
    final message = Message.fromJson(data);
    setState(() => messages.add(message));
  },
);

// Don't forget to unsubscribe
@override
void dispose() {
  realtimeService.unsubscribe(key);
  super.dispose();
}
```

---

## 🎯 Common Patterns

### Pattern 1: Photo Upload in Violation Report
```dart
class _ReportDialog extends StatefulWidget {
  String? _photoUrl;
  
  Widget build(context) {
    return AlertDialog(
      content: Column(
        children: [
          TextFormField(...), // Description
          FileUploadWidget(
            bucket: 'violation-photos',
            folder: communityId,
            fileType: FileType.image,
            maxSizeBytes: 5 * 1024 * 1024,
            onUploadComplete: (url) => _photoUrl = url,
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            await repo.createViolation(
              violation.copyWith(photoUrl: _photoUrl),
            );
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}
```

### Pattern 2: Live Chat with Realtime
```dart
class _ChatPage extends StatefulWidget {
  String? _subscription;
  
  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }
  
  void _subscribeToMessages() {
    _subscription = realtimeService.subscribeToTicketMessages(
      ticketId: ticketId,
      onNewMessage: (data) {
        setState(() {
          messages.add(Message.fromJson(data));
        });
        _scrollToBottom();
      },
    );
  }
  
  @override
  void dispose() {
    if (_subscription != null) {
      realtimeService.unsubscribe(_subscription!);
    }
    super.dispose();
  }
}
```

### Pattern 3: Generate and Download PDF
```dart
ElevatedButton(
  onPressed: () async {
    // Generate PDF
    final pdfService = PDFService();
    final pdfBytes = await pdfService.generatePoolAccessWaiver(
      community: community,
      registration: registration,
      userName: userName,
    );
    
    // Show preview (allows print/save)
    await pdfService.previewPDF(pdfBytes, 'pool_waiver.pdf');
  },
  child: Text('Download Waiver PDF'),
)
```

---

## 🔧 Setup Checklist

- [ ] Install dependencies: `flutter pub get`
- [ ] Apply realtime migration: `supabase db push`
- [ ] Create storage buckets in Supabase Dashboard
- [ ] Add storage RLS policies
- [ ] Add services to Provider setup
- [ ] Test file upload with `FileUploadWidget`
- [ ] Test PDF generation
- [ ] Test realtime subscription

---

## 📋 Storage Buckets to Create

| Bucket Name | Public | Purpose |
|-------------|--------|---------|
| `violation-photos` | ✅ Yes | Violation report images |
| `pool-documents` | ✅ Yes | Signed pool waivers |
| `payment-proofs` | ❌ No | Payment receipts |
| `community-logos` | ✅ Yes | Branding assets |

---

## 🔐 Storage Policy Template

```sql
-- Upload policy
CREATE POLICY "Users can upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'bucket-name');

-- View policy
CREATE POLICY "Users can view"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'bucket-name');

-- Delete policy (staff only)
CREATE POLICY "Staff can delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'bucket-name' 
  AND is_community_staff(auth.uid(), (storage.foldername(name))[1]::uuid)
);
```

---

## 🚨 Common Errors & Fixes

### "File data is null"
**Cause**: `file.bytes` is null (usually on mobile)
**Fix**: Use `withData: true` in FilePicker or use `image_picker` for mobile

### "No rows returned"
**Cause**: Storage bucket doesn't exist or no RLS policy
**Fix**: Create bucket and add policies in Supabase Dashboard

### "Invalid bearer token"
**Cause**: User not authenticated
**Fix**: Ensure user is logged in before uploading

### "Realtime not receiving updates"
**Cause**: Table not added to publication
**Fix**: Run migration `ALTER PUBLICATION supabase_realtime ADD TABLE table_name;`

---

## 💡 Pro Tips

1. **File Sizes**: Always validate file size before uploading
2. **Realtime Cleanup**: Always unsubscribe in `dispose()`
3. **PDF Performance**: Large PDFs may lag on web, show loading indicator
4. **Image Optimization**: Consider compressing images before upload
5. **Storage Costs**: Monitor usage in Supabase Dashboard
6. **Realtime Limits**: Each subscription uses a DB connection
7. **Error Handling**: Wrap uploads in try-catch, show user-friendly errors

---

## 📚 Full Documentation

- See `docs/ADVANCED_FEATURES.md` for detailed guides
- See `docs/IMPLEMENTATION_SUMMARY_ADVANCED_FEATURES.md` for overview
