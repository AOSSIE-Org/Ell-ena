function asset(path) {
  const base = document.querySelector("base")?.href ?? `${location.origin}/`;
  return new URL(path, base).href;
}

window.ellenaMountSupport = (element, theme) => {
  const SupportUsButton = window["support-us-button"];
  if (!SupportUsButton || !window.React || !window.ReactDOM) {
    element.textContent = "Could not load the support panel.";
    return function () {};
  }

  const root = ReactDOM.createRoot(element);
  root.render(
    React.createElement(SupportUsButton, {
      Theme: theme === "dark" ? "dark" : "light",
      Logo: true,
      projectInformation: {
        name: "Ell-ena",
        image: asset("icons/Icon-512.png"),
        description:
          "Ell-ena is an AI-powered teammate that turns chats and meetings into tasks, tickets and summaries, so your team never loses context.",
      },
      organizationInformation: {
        name: "AOSSIE",
        image: asset("aossie-logo.png"),
        link: "https://aossie.org",
        desc: "AOSSIE is a non-profit organization dedicated to building impactful open-source software, mentoring contributors, and fostering innovation through global collaboration.",
      },
      sponsors: [{ name: "Google Summer of Code" }],
      ctaSection: {
        sponsorLink: [
          { name: "Support Now", url: "https://buymeacoffee.com/aossie" },
        ],
      },
    }),
  );

  return function () {
    root.unmount();
  };
};
