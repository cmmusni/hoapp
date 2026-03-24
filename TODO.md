# HOApp Development TODO List

This document tracks features that need full implementation beyond the MVP scaffold.

## 🔴 High Priority

### Core Repositories (core_data)
- [x] ✅ Implement `ViolationRepository` (CRUD operations)
- [x] ✅ Implement `TicketRepository` with message threading
- [x] ✅ Implement `AmenityRepository` with booking logic
- [x] ✅ Implement `BillingRepository` (invoices & payments)
- [x] ✅ Implement `PoolAccessRepository` with PDF generation
- [x] ✅ Implement `HouseholdRepository` (members CRUD)

### Web Portal Features
- [x] ✅ Announcements: Full CRUD with pin/schedule
- [x] ✅ Violations: Anonymous submission + staff workflow
- [x] ✅ Tickets: Threaded chat with attachments
- [x] ✅ Amenities: Calendar view + booking form
- [x] ✅ Billing: Invoice creation + payment verification UI
- [x] ✅ Pool Access: Registration form + PDF generation + 3-month lock
- [x] ✅ Households: Unit management + member list/add/remove
- [x] ✅ Manage Users: Invite form with unit selector + invite link display
- [x] ✅ Settings: Community branding editor
- [x] ✅ Dashboard: Stats + recent activity widgets

### Mobile App Features
- [x] ✅ Announcements feed with realtime updates
- [x] ✅ Violations: Submit with photo upload
- [x] ✅ Tickets: Chat interface with attachments
- [x] ✅ Amenities: Booking flow with pool access check
- [x] ✅ My Household: List members + invite by email
- [x] ✅ Pool Access: Registration form + PDF viewer
- [x] ✅ Billing: Invoice list + GCash proof upload + receipt viewer
- [x] ✅ Deep link handling for invite acceptance

## 🟡 Medium Priority

### Advanced Features
- [x] ✅ PDF generation service (invoices, waivers)
- [x] ✅ File upload service with Supabase Storage
- [x] ✅ Realtime subscriptions for live updates
- [x] ✅ FileUploadWidget and ImageUploadWidget
- [x] ✅ Integrate file uploads in violations (photos)
- [x] ✅ Integrate file uploads in pool access (signed documents)
- [x] ✅ Integrate file uploads in billing (payment proofs)
- [x] ✅ Enable realtime in tickets (live chat)
- [x] ✅ Enable realtime in announcements (instant updates)

### UI/UX Enhancements
- [x] ✅ Loading states and error boundaries
- [x] ✅ Form validation and user feedback
- [x] ✅ Image/file upload with progress (widgets created)
- [x] ✅ Date/time pickers for bookings
- [x] ✅ Community branding theme switcher
- [x] ✅ Responsive layouts (mobile, tablet, desktop)

### Edge Functions
- [x] ✅ Error handling improvements
- [x] ✅ Rate limiting
- [x] ✅ Email notifications for invites
- [x] ✅ Webhook for payment verification
- [x] ✅ Batch operations support

### Testing
- [ ] Unit tests for repositories
- [ ] Widget tests for key screens
- [ ] Integration tests for auth flow
- [ ] E2E tests for booking workflow
- [ ] RLS policy tests

## 🟢 Low Priority / Future Enhancements

### Features
- [ ] Push notifications (mobile)
- [ ] In-app chat/messaging
- [ ] Document library
- [ ] Event calendar
- [ ] Voting/polls for HOA decisions
- [ ] Marketplace for residents
- [ ] Service provider directory
- [ ] Visitor registration
- [ ] Package tracking
- [ ] Maintenance request tracking

### Technical Debt
- [ ] Add code generation for models (`build_runner`)
- [ ] Implement proper state management (Riverpod/Bloc)
- [ ] Add offline support with sync
- [x] Implement search functionality ✅
- [ ] Add filtering and sorting
- [x] Pagination for large lists ✅
- [ ] Caching strategies
- [ ] Performance monitoring
- [ ] Accessibility improvements

### DevOps
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Automated testing on PR
- [ ] Code coverage reporting
- [ ] Automated deployment to staging
- [ ] Database backup automation
- [ ] Monitoring and alerting setup

### Documentation
- [ ] API documentation
- [ ] Architecture diagrams
- [ ] User guides (admin, staff, resident)
- [ ] Video tutorials
- [ ] FAQ section

## 📝 Notes

### Code Generation
Run this to generate missing `.g.dart` files for JSON serialization:
```bash
cd packages/core_domain
flutter pub run build_runner build --delete-conflicting-outputs
```

### Database Migrations
When adding new tables or columns:
```bash
cd supabase
supabase migration new add_feature_name
# Edit the generated SQL file
make db:push
```

### Adding Dependencies
Update `pubspec.yaml` in the appropriate package, then:
```bash
make install
```

---

**Next Steps for Developer:**

1. **Run code generation** to create `.g.dart` files
2. **Implement repositories** in `core_data` package
3. **Build UI screens** for web portal and mobile
4. **Test end-to-end flows** (signup → create community → invite → booking)
5. **Deploy to staging** environment for testing
6. **Gather feedback** and iterate

The scaffold provides a solid foundation with:
✅ Database schema with RLS
✅ Edge Functions for key operations
✅ Domain models and structure
✅ Auth and routing setup
✅ Theme and shared components
✅ Build configuration for web, Android, iOS

Focus on filling in the TODO sections to bring features to full functionality!
