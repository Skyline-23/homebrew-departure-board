import copy from "@/features/product/copy.json";
import site from "@/generated/site.json";

export function metadataFor(language) {
  const text = copy[language];
  const url = language === "ko" ? "/ko.html" : "/";
  const image = `/og-${language}-v1.png?v=${site.version}`;
  return {
    metadataBase: new URL("https://dpboard.skyline23.com"),
    title: text.title,
    description: text.description,
    icons: { icon: site.icon },
    alternates: { canonical: url, languages: { en: "/", ko: "/ko.html" } },
    openGraph: {
      title: "Departure Board",
      description: text.description,
      url,
      type: "website",
      siteName: "Departure Board",
      locale: language === "ko" ? "ko_KR" : "en_US",
      alternateLocale: language === "ko" ? "en_US" : "ko_KR",
      images: [
        {
          url: image,
          width: 1200,
          height: 630,
          type: "image/png",
          alt: text.description,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: "Departure Board",
      description: text.description,
      images: [image],
    },
  };
}
