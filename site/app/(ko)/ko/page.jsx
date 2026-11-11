import ProductPage from "../../../components/ProductPage";
import { metadataFor } from "../../../components/metadata";

export const metadata = metadataFor("ko");

export default function Page() {
  return <ProductPage language="ko" />;
}
