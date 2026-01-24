chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "copyRaw",
    title: "Copy Raw Content",
    contexts: ["page", "link"],
    documentUrlPatterns: ["https://github.com/*"]
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === "copyRaw") {
    // 1. Determine the URL
    // If the user right-clicked a specific link, use that.
    // Otherwise, use tab.url (Address Bar) which is more reliable for current branch state than info.pageUrl
    let targetUrl = info.linkUrl || tab.url;

    // 2. Clean the URL (remove line numbers like #L53)
    targetUrl = targetUrl.split('#')[0].split('?')[0];

    // 3. Convert to Raw URL using Regex for safety
    // Matches: github.com / User / Repo / blob / Branch / Path
    const githubRegex = /^https?:\/\/github\.com\/([^\/]+)\/([^\/]+)\/blob\/(.+)$/;
    const match = targetUrl.match(githubRegex);

    if (!match) {
      injectAlert(tab.id, "Not a valid GitHub file URL.");
      return;
    }

    // Construct: raw.githubusercontent.com / User / Repo / Branch / Path
    const rawUrl = `https://raw.githubusercontent.com/${match[1]}/${match[2]}/${match[3]}`;

    try {
      // 4. Fetch with 'no-store' to prevent caching old branch content
      const response = await fetch(rawUrl, { cache: "no-store" });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status} - Verify file exists on this branch`);
      }
      
      const text = await response.text();

      // 5. Inject script to copy
      await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: copyToClipboard,
        args: [text]
      });

    } catch (err) {
      console.error("Copy failed:", err);
      injectAlert(tab.id, `Error: ${err.message}`);
    }
  }
});

// Helper to inject alerts
function injectAlert(tabId, message) {
  chrome.scripting.executeScript({
    target: { tabId },
    func: (msg) => alert(msg),
    args: [message]
  });
}

// Function running inside the page
async function copyToClipboard(text) {
  try {
    await navigator.clipboard.writeText(text);
    // Optional: Show a temporary visual indicator instead of an alert
    const div = document.createElement('div');
    div.textContent = "Raw Copied!";
    div.style.cssText = "position:fixed; top:20px; right:20px; background:#2da44e; color:white; padding:10px 20px; border-radius:6px; z-index:9999; font-family:sans-serif; font-weight:bold; box-shadow:0 4px 12px rgba(0,0,0,0.15);";
    document.body.appendChild(div);
    setTimeout(() => div.remove(), 2000);
  } catch (err) {
    alert('Clipboard permission denied');
  }
}