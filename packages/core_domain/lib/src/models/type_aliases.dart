// Type aliases for UI compatibility
// This file provides backward compatibility for UI code that uses different type names

import 'pool_access.dart';
import 'household_member.dart';

// PoolAccess is actually PoolAccessRegistration in the domain model
typedef PoolAccess = PoolAccessRegistration;

// HouseholdRole is actually MemberRole in the domain model  
typedef HouseholdRole = MemberRole;
