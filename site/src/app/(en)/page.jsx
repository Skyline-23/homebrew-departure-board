import ProductPage from "@/features/product/ProductPage";
import { metadataFor } from "@/features/product/metadata";

export const metadata = metadataFor("en");

export default function Page() {
  return <ProductPage language="en" />;
}
