import {createClient} from "@/lib/supabase/server";
import {NextResponse} from "next/server";
export async function GET(request:Request){
 const url=new URL(request.url),code=url.searchParams.get("code"),supabase=await createClient();
 if(code){const {error}=await supabase.auth.exchangeCodeForSession(code);if(error)return NextResponse.redirect(new URL("/login?error=Email%20verification%20failed.%20Please%20try%20again.",url));}
 const {data:{user}}=await supabase.auth.getUser();
 if(!user)return NextResponse.redirect(new URL("/login?error=Please%20sign%20in%20to%20continue.",url));
 const meterNumber=String(user.user_metadata?.meter_number??"").trim().toUpperCase();
 if(meterNumber){const {error}=await supabase.rpc("claim_meter",{meter_number_input:meterNumber});if(error){console.error("Verified signup meter claim failed:",error.code,error.message);return NextResponse.redirect(new URL("/login?error=Account%20verified%2C%20but%20meter%20linking%20needs%20utility%20support.",url));}}
 return NextResponse.redirect(new URL("/dashboard",url));
}
