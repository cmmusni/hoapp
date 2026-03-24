// Shared utilities for Edge Functions
// Error handling, rate limiting, and common helpers

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

export interface ErrorResponse {
  ok: false
  error: string
  code?: string
}

export interface  SuccessResponse<T = unknown> {
  ok: true
  data?: T
  [key: string]: any
}

export type ApiResponse<T = unknown> = ErrorResponse | SuccessResponse<T>

// CORS headers for all responses
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-user-token',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
}

/**
 * Standard JSON response helper
 */
export function jsonResponse<T>(data: T, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

/**
 * Error response helper with logging
 */
export function errorResponse(
  error: string,
  status = 400,
  code?: string,
  context?: Record<string, any>
): Response {
  console.error('Error:', error, code, context)
  return jsonResponse<ErrorResponse>({ ok: false, error, code }, status)
}

/**
 * Standard error handler wrapper
 */
export async function withErrorHandling<T>(
  handler: () => Promise<Response>,
  context?: string
): Promise<Response> {
  try {
    return await handler()
  } catch (err) {
    const error = err as Error
    console.error(`Error${context ? ` in ${context}` : ''}:`, error)
    
    // Handle specific error types
    if (error.message.includes('JWT')) {
      return errorResponse('Invalid or expired token', 401, 'AUTH_ERROR')
    }
    
    if (error.message.includes('permission')) {
      return errorResponse('Insufficient permissions', 403, 'PERMISSION_DENIED')
    }
    
    if (error.message.includes('not found')) {
      return errorResponse('Resource not found', 404, 'NOT_FOUND')
    }
    
    // Generic server error
    return errorResponse(
      'Internal server error',
      500,
      'INTERNAL_ERROR',
      { originalError: error.message }
    )
  }
}

/**
 * Validate authentication and return user
 * Accepts JWT from Authorization header OR from request body (_jwt field)
 */
export async function validateAuth(
  req: Request,
  body?: any
): Promise<{ user: any; supabase: SupabaseClient } | Response> {
  let authHeader = req.headers.get('Authorization')
  let token: string | null = null
  
  // Try to get JWT from Authorization header
  if (authHeader) {
    token = authHeader.replace('Bearer ', '')
    console.log('validateAuth - using Authorization header')
  }
  
  // Fallback to custom header if Authorization was stripped by edge gateway
  if (!token) {
    const customToken = req.headers.get('x-user-token')
    if (customToken) {
      token = customToken
      console.log('validateAuth - using x-user-token fallback')
    }
  }
  
  // Fallback to body if headers are stripped
  if (!token && body && body._jwt) {
    token = body._jwt
    console.log('validateAuth - using _jwt from body')
  }
  
  console.log('validateAuth - token:', token ? `${token.substring(0, 30)}...` : 'MISSING')
  
  if (!token) {
    return errorResponse('Missing authentication token', 401, 'MISSING_AUTH')
  }

  // Create client with the Authorization header so Supabase handles relay tokens
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    {
      global: {
        headers: { Authorization: `Bearer ${token}` },
      },
    }
  )

  console.log('validateAuth - calling getUser()')
  const { data: { user }, error } = await supabase.auth.getUser()
  
  console.log('validateAuth - getUser result:', {
    hasUser: !!user,
    error: error?.message || 'none',
    errorStatus: error?.status,
  })
  
  if (error || !user) {
    // If relay token failed, try with explicit token (from body)
    if (body?._jwt) {
      console.log('validateAuth - retrying with _jwt from body')
      const { data: { user: user2 }, error: error2 } = await supabase.auth.getUser(body._jwt)
      if (!error2 && user2) {
        return { user: user2, supabase }
      }
      console.log('validateAuth - body _jwt also failed:', error2?.message)
    }
    return errorResponse('Invalid or expired token', 401, 'INVALID_TOKEN')
  }

  return { user, supabase }
}

/**
 * Create admin Supabase client
 */
export function createAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )
}

/**
 * Simple in-memory rate limiter (resets on function restart)
 * For production, use Redis or Supabase edge function with durable objects
 */
const rateLimitStore = new Map<string, { count: number; resetAt: number }>()

export interface RateLimitConfig {
  maxRequests: number
  windowMs: number
  key?: string
}

export function checkRateLimit(
  identifier: string,
  config: RateLimitConfig
): { allowed: boolean; remaining: number; resetAt: number } {
  const now = Date.now()
  const key = config.key ? `${config.key}:${identifier}` : identifier
  
  let entry = rateLimitStore.get(key)
  
  // Reset if window expired
  if (!entry || now > entry.resetAt) {
    entry = {
      count: 0,
      resetAt: now + config.windowMs,
    }
    rateLimitStore.set(key, entry)
  }
  
  // Check limit
  if (entry.count >= config.maxRequests) {
    return {
      allowed: false,
      remaining: 0,
      resetAt: entry.resetAt,
    }
  }
  
  // Increment and allow
  entry.count++
  
  return {
    allowed: true,
    remaining: config.maxRequests - entry.count,
    resetAt: entry.resetAt,
  }
}

/**
 * Rate limit middleware
 */
export function withRateLimit(
  identifier: string,
  config: RateLimitConfig
): Response | null {
  const result = checkRateLimit(identifier, config)
  
  if (!result.allowed) {
    const retryAfter = Math.ceil((result.resetAt - Date.now()) / 1000)
    return new Response(
      JSON.stringify({
        ok: false,
        error: 'Rate limit exceeded',
        code: 'RATE_LIMIT_EXCEEDED',
        retryAfter,
      }),
      {
        status: 429,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Retry-After': retryAfter.toString(),
          'X-RateLimit-Limit': config.maxRequests.toString(),
          'X-RateLimit-Remaining': '0',
          'X-RateLimit-Reset': new Date(result.resetAt).toISOString(),
        },
      }
    )
  }
  
  return null
}

/**
 * Validate required fields in request body
 */
export function validateRequired<T extends Record<string, any>>(
  body: T,
  requiredFields: (keyof T)[]
): string[] {
  const missing: string[] = []
  
  for (const field of requiredFields) {
    if (body[field] === undefined || body[field] === null || body[field] === '') {
      missing.push(field as string)
    }
  }
  
  return missing
}

/**
 * Audit log helper
 */
export async function createAuditLog(
  supabase: SupabaseClient,
  params: {
    communityId: string
    actorUserId: string
    action: string
    entity: string
    entityId?: string
    meta?: Record<string, any>
  }
): Promise<void> {
  try {
    await supabase.from('audit_logs').insert({
      community_id: params.communityId,
      actor_user_id: params.actorUserId,
      action: params.action,
      entity: params.entity,
      entity_id: params.entityId,
      meta: params.meta || {},
    })
  } catch (error) {
    console.error('Failed to create audit log:', error)
    // Non-fatal - don't throw
  }
}
