import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
export async function middleware(request: NextRequest) {
 let response = NextResponse.next({ request });
 const supabase = createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, { cookies: { getAll: () => request.cookies.getAll(), setAll: values => values.forEach(({name,value}) => { request.cookies.set(name,value); response.cookies.set(name,value); }) } });
 const { data: { user } } = await supabase.auth.getUser();
 if (!user && (request.nextUrl.pathname.startsWith("/dashboard") || request.nextUrl.pathname.startsWith("/admin"))) return NextResponse.redirect(new URL("/login", request.url));
 if (user && request.nextUrl.pathname.startsWith("/admin")) { const {data: profile} = await supabase.from("profiles").select("role").eq("id",user.id).single(); if(profile?.role !== "admin") return NextResponse.redirect(new URL("/dashboard",request.url)); }
 return response;
}
export const config = { matcher: ["/dashboard/:path*", "/admin/:path*"] };
