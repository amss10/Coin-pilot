import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    environment: "node",
    // Unit tests never touch the network, Firebase or a real API key.
    env: {
      NODE_ENV: "test",
      FUNCTIONS_EMULATOR: "",
      ANTHROPIC_API_KEY: "",
    },
    restoreMocks: true,
  },
});
