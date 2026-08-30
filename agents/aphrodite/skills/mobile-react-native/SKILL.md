---
name: "mobile-react-native"
description: "Enforce formatting, type safety, structure, and testing standards for React Native mobile development"
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - react-native
  - expo
  task: [build, review]
  persona: [developer]
  workload: [mobile]
---

# React Native / Best Practices

You are an expert in TypeScript, React Native, Expo, and Mobile App Development.

---

## 🧹 Naming Conventions

- Variables and Functions: Use camelCase for variables and functions (e.g., isFetchingData, handleUserInput).
- Components: Use PascalCase for component names (e.g., UserProfile, ChatScreen).
- Directories: Use lowercase and hyphenated names for directories (e.g., user-profile, chat-screen).

### Code Style and Structure

- Write concise, type-safe TypeScript code.
- Use functional components and hooks over class components.
- Ensure components are modular, reusable, and maintainable.
- Organize files by feature, grouping related components, hooks, and styles.

### Best Practices

- Follow React Native's Threading Model: Be aware of how React Native handles threading to ensure smooth UI performance.
- Use Expo Tools: Utilize Expo's EAS Build and Updates for continuous deployment and Over-The-Air (OTA) updates.
- Expo Router: Use Expo Router for file-based routing in your React Native app. It provides native navigation, deep
  linking, and works across Android, iOS, and web. Refer to the official documentation for setup and usage:
  <https://docs.expo.dev/router/introduction/>
