import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "Maji Bill | Water billing", description: "Water utility billing and meter services" };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="en"><body>{children}</body></html>; }
