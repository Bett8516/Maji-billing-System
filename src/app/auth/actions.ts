"use server";
import {redirect} from "next/navigation";
import {headers} from "next/headers";
import {z} from "zod";
import {createClient} from "@/lib/supabase/server";

const loginSchema=z.object({email:z.email(),password:z.string().min(8)});
export async function login(form:FormData){
 const parsed=loginSchema.safeParse(Object.fromEntries(form));
 if(!parsed.success)redirect("/login?error=Check%20your%20email%20and%20password");
 const supabase=await createClient(),{error}=await supabase.auth.signInWithPassword(parsed.data);
 if(error)redirect("/login?error=Email%20or%20password%20is%20incorrect");
 const {data:{user}}=await supabase.auth.getUser(),{data:profile}=await supabase.from("profiles").select("role").eq("id",user!.id).single();
 redirect(profile?.role==="admin"?"/admin":"/dashboard");
}

export async function register(form:FormData){
 const schema=z.object({full_name:z.string().min(2),phone:z.string().min(7),meter_number:z.string().min(3),email:z.email(),password:z.string().min(8)});
 const parsed=schema.safeParse(Object.fromEntries(form));
 if(!parsed.success)redirect("/register?error=Please%20check%20all%20fields%20and%20use%208%2B%20character%20password");
 const supabase=await createClient(),meterNumber=parsed.data.meter_number.trim().toUpperCase();
 const {data:available,error:availabilityError}=await supabase.rpc("meter_available",{meter_number_input:meterNumber});
 if(availabilityError){console.error("Registration meter lookup failed:",availabilityError.code,availabilityError.message);redirect("/register?error=Database%20setup%20incomplete%3A%20check%20the%20Supabase%20migration%20and%20server%20logs");}
 if(!available)redirect("/register?error=Meter%20not%20found%2C%20inactive%2C%20or%20already%20linked");
 const origin=(await headers()).get("origin")??"http://localhost:3000";
 const {data,error}=await supabase.auth.signUp({email:parsed.data.email,password:parsed.data.password,options:{emailRedirectTo:`${origin}/auth/callback`,data:{full_name:parsed.data.full_name,phone:parsed.data.phone,meter_number:meterNumber}}});
 if(error||!data.user){console.error("Registration signup failed:",error?.code,error?.message);redirect("/register?error=Could%20not%20create%20account%3A%20check%20server%20logs");}
 if(data.session){const {error:linkError}=await supabase.rpc("claim_meter",{meter_number_input:meterNumber});if(linkError){console.error("Registration meter claim failed:",linkError.code,linkError.message);redirect("/register?error=Account%20created%20but%20meter%20link%20failed%3A%20check%20server%20logs");}redirect("/dashboard");}
 redirect("/login?message=Check%20your%20email%20to%20verify%20your%20account%20and%20finish%20registration.");
}
