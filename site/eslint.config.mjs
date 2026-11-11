import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";

export default defineConfig([
  ...nextVitals,
  {
    files: ["src/features/product/ProductPage.jsx"],
    rules: {
      // Static hosting uses prebuilt responsive images and full-document locale links.
      "@next/next/no-img-element": "off",
      "@next/next/no-html-link-for-pages": "off",
    },
  },
  { rules: { "no-nested-ternary": "error", "no-void": "error" } },
  globalIgnores([".next/**", "out/**", "public/**", "src/generated/**"]),
]);
