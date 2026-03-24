import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  withErrorHandling,
  validateAuth,
  createAdminClient,
  withRateLimit,
  createAuditLog,
} from '../_shared/utils.ts'

interface BatchOperation {
  id: string
  operation: 'create' | 'update' | 'delete'
  entity: 'announcement' | 'invoice' | 'ticket' | 'amenity_booking'
  data?: Record<string, any>
}

interface BatchRequest {
  community_id: string
  operations: BatchOperation[]
}

interface BatchResult {
  id: string
  success: boolean
  data?: any
  error?: string
}

interface BatchResponse {
  ok: boolean
  results: BatchResult[]
  successful: number
  failed: number
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  return withErrorHandling(async () => {
    // Validate authentication
    const authResult = await validateAuth(req)
    if (authResult instanceof Response) return authResult
    const { user } = authResult

    // Rate limiting: 5 batch operations per minute per user
    const rateLimitResponse = withRateLimit(user.id, {
      maxRequests: 5,
      windowMs: 60 * 1000, // 1 minute
      key: 'batch_operations',
    })
    if (rateLimitResponse) return rateLimitResponse

    // Parse request body
    const body: BatchRequest = await req.json()
    
    if (!body.community_id || !body.operations || !Array.isArray(body.operations)) {
      return errorResponse(
        'Missing or invalid required fields',
        400,
        'INVALID_REQUEST'
      )
    }

    // Limit batch size
    if (body.operations.length > 100) {
      return errorResponse(
        'Batch size cannot exceed 100 operations',
        400,
        'BATCH_SIZE_EXCEEDED'
      )
    }

    const supabaseAdmin = createAdminClient()

    // Check if user is staff in the community
    const { data: userRoles } = await supabaseAdmin
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('community_id', body.community_id)

    const isStaff = userRoles?.some(r =>
      ['community_admin', 'hoa_officer'].includes(r.role)
    )

    if (!isStaff) {
      return errorResponse(
        'Only staff can perform batch operations',
        403,
        'INSUFFICIENT_PERMISSIONS'
      )
    }

    const results: BatchResult[] = []
    let successful = 0
    let failed = 0

    // Process each operation
    for (const op of body.operations) {
      try {
        const result = await processBatchOperation(
          supabaseAdmin,
          body.community_id,
          user.id,
          op
        )
        results.push(result)
        if (result.success) successful++
        else failed++
      } catch (error) {
        results.push({
          id: op.id,
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error',
        })
        failed++
      }
    }

    // Audit log for batch operation
    await createAuditLog(supabaseAdmin, {
      communityId: body.community_id,
      actorUserId: user.id,
      action: 'batch_operation',
      entity: 'system',
      meta: {
        total: body.operations.length,
        successful,
        failed,
        entities: [...new Set(body.operations.map(op => op.entity))],
      },
    })

    return jsonResponse<BatchResponse>({
      ok: true,
      results,
      successful,
      failed,
    })
  }, 'batch_operations')
})

async function processBatchOperation(
  supabase: any,
  communityId: string,
  userId: string,
  op: BatchOperation
): Promise<BatchResult> {
  const { id, operation, entity, data } = op

  try {
    switch (entity) {
      case 'announcement': {
        if (operation === 'create') {
          const { data: result, error } = await supabase
            .from('announcements')
            .insert({
              ...data,
              community_id: communityId,
              created_by: userId,
            })
            .select()
            .single()

          if (error) throw error
          return { id, success: true, data: result }
        } else if (operation === 'update') {
          if (!data?.announcement_id) {
            throw new Error('announcement_id required for update')
          }
          const { data: result, error } = await supabase
            .from('announcements')
            .update(data)
            .eq('id', data.announcement_id)
            .eq('community_id', communityId)
            .select()
            .single()

          if (error) throw error
          return { id, success: true, data: result }
        } else if (operation === 'delete') {
          if (!data?.announcement_id) {
            throw new Error('announcement_id required for delete')
          }
          const { error } = await supabase
            .from('announcements')
            .delete()
            .eq('id', data.announcement_id)
            .eq('community_id', communityId)

          if (error) throw error
          return { id, success: true }
        }
        break
      }

      case 'invoice': {
        if (operation === 'create') {
          const { data: result, error } = await supabase
            .from('invoices')
            .insert({
              ...data,
              community_id: communityId,
            })
            .select()
            .single()

          if (error) throw error
          return { id, success: true, data: result }
        } else if (operation === 'update') {
          if (!data?.invoice_id) {
            throw new Error('invoice_id required for update')
          }
          const { data: result, error } = await supabase
            .from('invoices')
            .update(data)
            .eq('id', data.invoice_id)
            .eq('community_id', communityId)
            .select()
            .single()

          if (error) throw error
          return { id, success: true, data: result }
        }
        break
      }

      case 'ticket': {
        if (operation === 'update') {
          if (!data?.ticket_id) {
            throw new Error('ticket_id required for update')
          }
          const { data: result, error } = await supabase
            .from('tickets')
            .update({ status: data.status })
            .eq('id', data.ticket_id)
            .eq('community_id', communityId)
            .select()
            .single()

          if (error) throw error
          return { id, success: true, data: result }
        }
        break
      }

      case 'amenity_booking': {
        if (operation === 'delete') {
          if (!data?.booking_id) {
            throw new Error('booking_id required for delete')
          }
          const { error } = await supabase
            .from('amenity_bookings')
            .delete()
            .eq('id', data.booking_id)
            .eq('community_id', communityId)

          if (error) throw error
          return { id, success: true }
        }
        break
      }

      default:
        throw new Error(`Unsupported entity: ${entity}`)
    }

    throw new Error(`Unsupported operation: ${operation} for ${entity}`)
  } catch (error) {
    return {
      id,
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    }
  }
}
