import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Multi-Tenant SaaS",
  description: "Multi-city tourist guide platform",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
