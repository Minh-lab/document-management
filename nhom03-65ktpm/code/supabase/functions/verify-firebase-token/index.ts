import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts";

// Firebase Project ID
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") || "your-firebase-project-id";

// Supabase JWT Secret
const SUPABASE_JWT_SECRET = Deno.env.get("SUPABASE_JWT_SECRET") || "your-supabase-jwt-secret";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const firebaseToken = authHeader.replace("Bearer ", "");
    
    // Verify Firebase ID token
    const firebaseKeysResponse = await fetch(
      `https://www.googleapis.com/robot/v1/metadata/x509/securetoken@${FIREBASE_PROJECT_ID}.iam.gserviceaccount.com`
    );
    const firebaseKeys = await firebaseKeysResponse.json();
    
    // Parse and verify JWT
    const [headerB64, payloadB64, signatureB64] = firebaseToken.split(".");
    const header = JSON.parse(atob(headerB64));
    const payload = JSON.parse(atob(payloadB64));
    
    // Verify signature
    const key = firebaseKeys[header.kid];
    if (!key) {
      throw new Error("Invalid key ID");
    }
    
    const publicKey = await crypto.subtle.importKey(
      "spki",
      str2ab(key),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    );
    
    const isValid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      publicKey,
      str2ab(signatureB64),
      str2ab(`${headerB64}.${payloadB64}`)
    );
    
    if (!isValid) {
      throw new Error("Invalid signature");
    }
    
    // Check expiration
    if (payload.exp * 1000 < Date.now()) {
      throw new Error("Token expired");
    }
    
    // Check audience
    if (payload.aud !== FIREBASE_PROJECT_ID) {
      throw new Error("Invalid audience");
    }
    
    // Check issuer
    if (payload.iss !== `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`) {
      throw new Error("Invalid issuer");
    }
    
    const firebaseUid = payload.sub;
    const email = payload.email || "";
    const name = payload.name || "";
    const picture = payload.picture || "";
    
    // Create Supabase JWT with Firebase UID
    const supabaseToken = await createSupabaseJwt(firebaseUid, email, name, picture);
    
    return new Response(JSON.stringify({ 
      token: supabaseToken,
      user: { uid: firebaseUid, email, name, picture }
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function createSupabaseJwt(uid: string, email: string, name: string, picture: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(SUPABASE_JWT_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"]
  );
  
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: uid,
    email,
    user_metadata: {
      full_name: name,
      avatar_url: picture,
      provider: "google"
    },
    role: "authenticated",
    iat: now,
    exp: now + 3600, // 1 hour
  };
  
  const encoder = new TextEncoder();
  const data = encoder.encode(JSON.stringify(payload));
  const signature = await crypto.subtle.sign("HMAC", key, data);
  
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payloadB64 = btoa(JSON.stringify(payload));
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)));
  
  return `${header}.${payloadB64}.${signatureB64}`;
}

function atob(b64: string): string {
  return new TextDecoder().decode(base64ToUint8Array(b64));
}

function btoa(str: string): string {
  return btoaUint8Array(new TextEncoder().encode(str));
}

function base64ToUint8Array(b64: string): Uint8Array {
  const binary = atob(b64.replace(/-/g, "+").replace(/_/g, "/"));
  const len = binary.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function btoaUint8Array(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function str2ab(str: string): ArrayBuffer {
  const buf = new ArrayBuffer(str.length);
  const bufView = new Uint8Array(buf);
  for (let i = 0; i < str.length; i++) {
    bufView[i] = str.charCodeAt(i);
  }
  return buf;
}