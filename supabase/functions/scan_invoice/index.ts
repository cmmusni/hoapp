import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  withErrorHandling,
  validateAuth,
} from '../_shared/utils.ts'

interface LineItem {
  label: string
  amount: number
  category: 'dues' | 'water' | 'amenity' | 'insurance' | 'other'
}

interface InvoiceData {
  description: string | null
  category: 'dues' | 'water' | 'amenity' | 'insurance' | 'other'
  amount: number
  line_items: LineItem[]
  due_date: string | null
  period_start: string | null
  period_end: string | null
  notes: string | null
  unit_number: string | null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  return withErrorHandling(async () => {
    const body = await req.json()

    // Validate authentication
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult

    const { image_base64 } = body
    if (!image_base64) {
      return errorResponse('Missing image_base64', 400, 'MISSING_FIELD')
    }

    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiKey) {
      return errorResponse(
        'OpenAI API key not configured',
        500,
        'CONFIG_ERROR'
      )
    }

    // Determine image media type from base64 header or default to jpeg
    let mediaType = 'image/jpeg'
    let base64Data = image_base64
    if (image_base64.startsWith('data:')) {
      const match = image_base64.match(
        /^data:(image\/[a-zA-Z+]+);base64,(.+)$/
      )
      if (match) {
        mediaType = match[1]
        base64Data = match[2]
      }
    }

    const systemPrompt = `You are an invoice data extraction assistant. Extract invoice details from the uploaded image ACCURATELY. Return ONLY valid JSON matching this exact schema:

{
  "description": "Brief description of the invoice (e.g., 'March 2026 Water Billing')",
  "category": "dues|water|amenity|insurance|other",
  "amount": 0.00,
  "line_items": [
    { "label": "Item description", "amount": 0.00, "category": "dues|water|amenity|insurance|other" }
  ],
  "due_date": "YYYY-MM-DD or null",
  "period_start": "YYYY-MM-DD or null",
  "period_end": "YYYY-MM-DD or null",
  "notes": "Any additional notes from the invoice or null",
  "unit_number": "Unit number or unit no. from the invoice, as a string, or null"
}

Rules:
- "amount" must be the TOTAL amount. If line items are present, it should equal the sum of line items.
- "category" must be one of: dues, water, amenity, insurance, other. Infer from context.
- "line_items" should list each billable item found. If only a total is visible, create a single line item.
- Each line item must have its own "category" (dues, water, amenity, insurance, or other). Infer from context for each item independently.
- Dates must be in YYYY-MM-DD format or null if not found.
- "unit_number" should be the unit number, unit no., or apartment number found on the invoice. Return as a string or null.
- All monetary amounts must be numbers (not strings). Use 2 decimal places.
- Return ONLY the JSON object with no markdown formatting, no code fences, no explanation.`

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: 'Extract the invoice data from this image.',
              },
              {
                type: 'image_url',
                image_url: {
                  url: `data:${mediaType};base64,${base64Data}`,
                },
              },
            ],
          },
        ],
        max_tokens: 1000,
        temperature: 0,
      }),
    })

    if (!response.ok) {
      const errText = await response.text()
      console.error('OpenAI API error:', response.status, errText)

      let errBody: any = {}
      try { errBody = JSON.parse(errText) } catch (_) {}
      const errCode = errBody?.error?.code || ''
      const errMsg = errBody?.error?.message || ''

      if (response.status === 429 || errCode === 'insufficient_quota' || errCode === 'rate_limit_exceeded') {
        return errorResponse(
          'AI service quota exceeded. Please contact your administrator to check the OpenAI API credits.',
          429,
          'QUOTA_EXCEEDED'
        )
      }

      if (response.status === 401 || errCode === 'invalid_api_key') {
        return errorResponse(
          'AI service authentication failed. Please contact your administrator.',
          502,
          'AUTH_FAILED'
        )
      }

      return errorResponse(
        `AI service error: ${errMsg || 'Failed to analyze image'}`,
        502,
        'OPENAI_ERROR'
      )
    }

    const result = await response.json()
    const content = result.choices?.[0]?.message?.content?.trim()

    if (!content) {
      return errorResponse(
        'No response from image analysis',
        502,
        'EMPTY_RESPONSE'
      )
    }

    // Parse the JSON response, stripping any markdown fences
    let invoiceData: InvoiceData
    try {
      const cleaned = content
        .replace(/^```json?\s*/i, '')
        .replace(/```\s*$/i, '')
        .trim()
      invoiceData = JSON.parse(cleaned)
    } catch (e) {
      console.error('Failed to parse OpenAI response:', content)
      return errorResponse(
        'Could not parse invoice data from image',
        422,
        'PARSE_ERROR'
      )
    }

    // Validate and sanitize the response
    const validCategories = ['dues', 'water', 'amenity', 'insurance', 'other']
    if (!validCategories.includes(invoiceData.category)) {
      invoiceData.category = 'other'
    }

    if (typeof invoiceData.amount !== 'number' || invoiceData.amount < 0) {
      invoiceData.amount = 0
    }

    if (!Array.isArray(invoiceData.line_items)) {
      invoiceData.line_items = []
    }

    // Ensure line items have valid structure
    invoiceData.line_items = invoiceData.line_items
      .filter((item) => item && typeof item.label === 'string')
      .map((item) => ({
        label: item.label.trim(),
        amount:
          typeof item.amount === 'number' && item.amount >= 0
            ? Math.round(item.amount * 100) / 100
            : 0,
        category: validCategories.includes(item.category) ? item.category : invoiceData.category,
      }))

    invoiceData.amount = Math.round(invoiceData.amount * 100) / 100

    return jsonResponse({ ok: true, data: invoiceData })
  }, 'scan_invoice')
})
