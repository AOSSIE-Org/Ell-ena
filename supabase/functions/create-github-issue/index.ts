import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req: Request) => {
  try {
    const body = await req.json();
    const title = body.title;
    const description = body.description;
    const ticketNumber = body.ticketNumber;

    const githubToken = Deno.env.get("GITHUB_TOKEN");
    const githubRepo = Deno.env.get("GITHUB_REPO");
    const githubOwner = Deno.env.get("GITHUB_OWNER");

    if (!githubToken || !githubOwner || !githubRepo) {
      return new Response(
        JSON.stringify({ error: "GitHub configuration missing" }),
        { status: 500 }
      );
    }

    const githubResponse = await fetch(
      `https://api.github.com/repos/${githubOwner}/${githubRepo}/issues`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${githubToken}`,
          "Content-Type": "application/json",
          "Accept": "application/vnd.github+json"
        },
        body: JSON.stringify({
          title: title,
          body: `Created from Ell-ena

Ticket: ${ticketNumber}

Description:
${description}`
        })
      }
    );

    const data = await githubResponse.json();

    return new Response(
      JSON.stringify({
        issue_number: data.number,
        issue_url: data.html_url
      }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500 }
    );
  }
});