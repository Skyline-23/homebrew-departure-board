import "../site.css";
import "../hero.css";

export default function Root({ language, children }) {
  return (
    <html lang={language}>
      <body
        className="editorial-product"
        data-theme="light"
        data-site-framework="next"
      >
        <noscript>
          <style>
            {
              ".airport-hero{height:auto;min-height:0}.hero-scene{position:relative;height:auto}.airport-route{visibility:hidden}"
            }
          </style>
        </noscript>
        {children}
      </body>
    </html>
  );
}
