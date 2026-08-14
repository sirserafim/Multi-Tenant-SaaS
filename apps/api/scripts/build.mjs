import * as esbuild from "esbuild";

await esbuild.build({
  entryPoints: ["src/index.ts"],
  bundle: true,
  platform: "node",
  target: "node20",
  format: "esm",
  outfile: "dist/index.js",
  sourcemap: true,
  // Bundle workspace contracts; leave runtime deps external.
  external: [
    "express",
    "cors",
    "helmet",
    "pg",
    "pg-native",
    "zod",
    "@supabase/supabase-js",
  ],
  banner: {
    js: "import { createRequire as __createRequire } from 'module'; const require = __createRequire(import.meta.url);",
  },
});

console.log("api bundle written to dist/index.js");
