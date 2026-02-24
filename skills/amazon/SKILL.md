---
name: amazon
description: Buy and return items on Amazon using browser automation. Use for purchasing, reordering, checking order history, and processing returns.
compatibility: Requires agent-browser CLI with Chrome DevTools Protocol (CDP). Chrome must be running with --remote-debugging-port. Optional VNC for headless setups.
---

# Amazon Ordering

## Prerequisites

- Browser logged into Amazon (use `agent-browser` with CDP on port 9222)
- If logged out, retrieve password from your password manager
- VNC access (if using headless): `ssh -L 6080:localhost:6080 <host>` then http://localhost:6080/vnc.html

## Setup

Set these environment variables or configure your defaults:

```bash
# Your default shipping address (verify on checkout)
export AMAZON_SHIPPING_ADDRESS="Your shipping address"
# Your preferred payment method description (verify on checkout)
export AMAZON_PAYMENT_METHOD="Your preferred card"
# Your preferred return drop-off location
export AMAZON_RETURN_DROPOFF="Whole Foods"
```

Always verify shipping address and payment method are correct before placing an order.

## Returns

### Default Answers (use unless user specifies otherwise)
- **Return reason:** "Changed Mind" → "My needs changed"
- **Packaging opened:** Yes
- **Item in original packaging:** Yes
- **Have you used the item:** Yes
- **Signs of use:** None
- **Battery leaks/overheating:** No
- **All accessories included:** Yes
- **Refund type:** Refund to original payment method (not replacement, not gift card)
- **Drop-off location:** Use `AMAZON_RETURN_DROPOFF` or Whole Foods

### Return Flow
1. Orders → Find item → "Return or replace items"
2. Select "Changed Mind" → "My needs changed" → Continue
3. Answer condition questions with defaults above
4. Continue past "Get Product Support" suggestions
5. Select "Refund to original payment method"
6. Select drop-off location
7. Confirm return
8. Done — QR code will be emailed

### Communication Style
- **Do NOT narrate each step** — just execute the whole return silently
- **Only message the user once it's confirmed** with a brief summary:
  - Item name
  - Refund amount
  - Drop-off location & deadline
- If something goes wrong or needs clarification, then ask

## Ordering Rules

### Reorders (items ordered before)
- Go directly to order history, search for item
- Click "Buy it again"
- Verify address and payment method
- **Place order without confirmation** — no screenshot needed

### New Items (never ordered before)
- Search or navigate to product
- **Send screenshot of product page** (scroll so price + product image visible, skip nav bars)
- Wait for user confirmation before adding to cart
- Verify address and payment method
- Place order after confirmation

## Workflow

### Connect to browser
```bash
agent-browser connect 9222
```

**Always open a new tab** — other sessions share the same Chrome. Use `--new-tab` on every `open` command.

### Search order history
```bash
agent-browser open "https://www.amazon.com/gp/your-account/order-history"
agent-browser snapshot -i
# Find search box, fill with item name, click search
```

### Reorder flow
```bash
# From order history search results
agent-browser click @[buy-it-again-ref]
# Wait for checkout page
agent-browser snapshot
# Verify correct address and payment method are selected
agent-browser click @[place-order-ref]
```

### Screenshot tips
- Scroll past nav bars before screenshotting
- Ensure price and product image are both visible
- Save screenshots to a temporary directory
- Send via message tool with caption

## Starting the browser (if not running)

```bash
# Linux (headless with Xvfb/VNC)
DISPLAY=:99 google-chrome --user-data-dir=$HOME/.config/chrome-openclaw --no-first-run --remote-debugging-port=9222 https://www.amazon.com &

# macOS (opens visible window)
open -na "Google Chrome" --args --user-data-dir=$HOME/.config/chrome-openclaw --no-first-run --remote-debugging-port=9222 https://www.amazon.com
```

## Notes

- Browser profile persists login at `$HOME/.config/chrome-openclaw`
- VNC display is `:99` on port 5999 (noVNC on 6080) — Linux headless only
- Order confirmations go to the email on your Amazon account
- CAPTCHAs or 2FA may require manual intervention — if browser is visible, ask the user to solve it
