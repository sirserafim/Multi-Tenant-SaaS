import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Contracts package ships TypeScript source — Next transpiles it in-process.
  transpilePackages: ["@multi-tenant-saas/contracts"],
};

export default nextConfig;
