import {GoogleGenAI} from "@google/genai";
import {createClient} from "@/lib/supabase/server";
import {NextResponse} from "next/server";
export const runtime="nodejs";
export async function POST(request:Request){
 try{
  const supabase=await createClient(),{data:{user}}=await supabase.auth.getUser();
  if(!user)return NextResponse.json({error:"Please sign in first."},{status:401});
  const form=await request.formData(),file=form.get("photo");
  if(!(file instanceof File)||!file.type.startsWith("image/"))return NextResponse.json({error:"Choose a clear meter photo."},{status:400});
  if(!["image/jpeg","image/png","image/webp"].includes(file.type))return NextResponse.json({error:"Use a JPEG, PNG or WebP photo."},{status:400});
  if(file.size>5*1024*1024)return NextResponse.json({error:"Photo must be smaller than 5 MB."},{status:413});
  if(!process.env.GEMINI_API_KEY)return NextResponse.json({error:"Free meter photo reading is not configured. Please enter the reading manually."},{status:503});
  const ai=new GoogleGenAI({apiKey:process.env.GEMINI_API_KEY}),image=Buffer.from(await file.arrayBuffer()).toString("base64");
  const response=await ai.models.generateContent({
   model:"gemini-3.8-flash",
   contents:[{role:"user",parts:[{inlineData:{mimeType:file.type,data:image}},{text:"Read the water meter in this photo. Return the visible meter number and current cumulative reading. Do not guess; use null for unreadable fields. Respond only as JSON with keys meter_number (string or null), reading (number or null), confidence (number from 0 to 1)."}]}],
   config:{systemInstruction:"You extract water meter readings from images. Report only digits and markings that are actually visible. Never infer missing digits.",maxOutputTokens:200,responseMimeType:"application/json"}
  });
  const parsed=JSON.parse(response.text??"{}");
  if(parsed.reading===null||parsed.reading===undefined||!Number.isFinite(Number(parsed.reading))||!parsed.meter_number)return NextResponse.json({error:"We could not read both the meter number and reading. Try better lighting or enter the reading manually."},{status:422});
  return NextResponse.json({meter_number:String(parsed.meter_number).trim(),reading:Number(parsed.reading),confidence:Math.max(0,Math.min(1,Number(parsed.confidence)||0))});
 }catch(error){console.error("meter OCR failed",error);return NextResponse.json({error:"Unable to read this photo. Try another image or enter the reading manually."},{status:500});}
}
