# CopilotMonitor

<p align="center">
  <img src="./docs/banner-1024.png" alt="CopilotMonitor" width="220" />
</p>

<p align="center">
  <b>Monitor your GitHub Copilot usage right from your macOS menu bar</b>
</p>

`CopilotMonitor` is a lightweight utility that lets you track your real-time GitHub Copilot usage and remaining quota directly from the macOS menu bar.

## ✨ Key Features

- **Menu Bar Icon:** Displays your current usage percentage (%) at a glance.
- **Detailed Insights:** Check your subscription plan, usage reset date, and remaining interaction count.
- **Auto-Refresh:** Automatically updates your data every 30 seconds to stay current.
- **Simple Login:** No complex API tokens required. Connect easily using a standard web login.
- **Native Experience:** Designed as a menu-bar-only app to stay out of your way.

## ⚙️ How It Works

`CopilotMonitor` simplifies the setup process. Instead of asking for personal access tokens, it uses a built-in login window. Once you **log in to your GitHub account** through the app, it securely retrieves your subscription and quota information to display in the menu bar.

## 📋 Requirements

- **macOS:** 15.6 or later
- **Account:** A GitHub account with an active GitHub Copilot subscription

## 🚀 Getting Started

1. Launch the app, and a `0%` icon will appear in your menu bar.
2. Click the icon and select **Login with GitHub**.
3. Sign in to your GitHub account as you normally would in a browser.
4. Once logged in, you can monitor your usage in real-time!

## 💡 Information Guide

- **Status:** Shows your current login and connection status.
- **Plan:** Displays your Copilot subscription tier (e.g., Individual, Business).
- **Reset:** The date when your monthly usage quota will reset to zero.
- **Remaining:** The number of high-performance model interactions (Premium Interactions) left for the current period.

---

### Notes

- This is not an official GitHub application.
- If your session expires or information stops updating, simply click `Clear Stored Session` and log in again.
