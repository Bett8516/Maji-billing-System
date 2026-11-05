import {createClient} from "@/lib/supabase/server";
import {NextResponse} from "next/server";
import {z} from "zod";
export async function POST(req:Request){
 const supabase=await createClient(),{data:{user}}=await supabase.auth.getUser();
 if(!user)return NextResponse.json({error:"Sign in required"},{status:401});
 let body:unknown;try{body=await req.json()}catch{return NextResponse.json({error:"Invalid request body"},{status:400})}
 const parsed=z.object({meter_id:z.uuid(),reading_value:z.number().nonnegative(),source:z.enum(["photo","manual"]),photo_url:z.string().optional(),ocr_confidence:z.number().min(0).max(1).optional()}).safeParse(body);
 if(!parsed.success)return NextResponse.json({error:"Enter a valid meter reading"},{status:400});
 const {data,error}=await supabase.rpc("submit_reading",{meter_id_input:parsed.data.meter_id,reading_value_input:parsed.data.reading_value,source_input:parsed.data.source,photo_url_input:parsed.data.photo_url??null,ocr_confidence_input:parsed.data.ocr_confidence??null});
 if(error)return NextResponse.json({error:"Could not save this reading. Check your meter and try again."},{status:400});
 const reading=Array.isArray(data)?data[0]:data;return NextResponse.json(reading);
}
