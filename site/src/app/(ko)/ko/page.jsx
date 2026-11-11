import ProductPage from "@/features/product/ProductPage";
import { metadataFor } from "@/features/product/metadata";

export const metadata = metadataFor("ko");

export default function Page() {
  return <ProductPage language="ko" />;
}
