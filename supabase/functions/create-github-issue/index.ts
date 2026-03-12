import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { title, description, category, priority, ticketId } = await req.json()
    
    const githubToken = Deno.env.get('GITHUB_ACCESS_TOKEN')
    const repoOwner = Deno.env.get('GITHUB_REPO_OWNER')
    const repoName = Deno.env.get('GITHUB_REPO_NAME')

    if (!githubToken || !repoOwner || !repoName) {
      throw new Error("GitHub configuration is missing in environment variables.")
    }

    const githubApiUrl = `https://api.github.com/repos/${repoOwner}/${repoName}/issues`

    const response = await fetch(githubApiUrl, {
      method: "POST",
      headers: {
        "Accept": "application/vnd.github+json",
        "Authorization": `Bearer ${githubToken}`,
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        title: `[${category}] ${title}`,
        body: `**Ticket ID:** ${ticketId}\n**Priority:** ${priority}\n\n${description || 'No description provided.'}`,
        labels: [category?.toLowerCase() || 'bug', priority?.toLowerCase() || 'medium']
      })
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error(`GitHub API Error: ${response.status} ${errorText}`)
      throw new Error(`GitHub API failed with status ${response.status}`)
    }

    const data = await response.json()

    return new Response(
      JSON.stringify({
        success: true,
        issueNumber: data.number.toString(),
        issueUrl: data.html_url
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error("Edge Function Error:", errorMessage)
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500, // Return 500 but handled gracefully by the client
      }
    )
  }
})
