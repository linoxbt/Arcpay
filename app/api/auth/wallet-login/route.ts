import { type NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/utils/supabase/server";
import { createHash } from "crypto";
import { SiweMessage } from 'siwe';

export async function POST(req: NextRequest) {
  try {
    const { message, signature } = await req.json();

    if (!message || !signature) {
      return NextResponse.json(
        { error: "Message and signature are required." },
        { status: 400 }
      );
    }

    const siweMessage = new SiweMessage(message);
    const { data: fields, success } = await siweMessage.verify({ signature });

    if (!success) {
      return NextResponse.json(
        { error: "Invalid signature." },
        { status: 401 }
      );
    }

    const walletAddress = fields.address;

    const supabase = await createClient();

    // Check if the user exists or needs to be registered
    const { data: wallets, error: walletsError } = await supabase
      .from("wallets")
      .select("profile_id, wallet_address");

    let isNewUser = true;
    if (wallets && !walletsError) {
      const existingWallet = wallets.find(
        (w) => w.wallet_address.toLowerCase() === walletAddress.toLowerCase()
      );
      if (existingWallet) {
        isNewUser = false;
      }
    }

    // Generate deterministic credentials
    const email = `wallet_${walletAddress.toLowerCase()}@arcpay.eth`;
    const hash = createHash("sha256");
    hash.update(walletAddress.toLowerCase() + (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "arcpay_salt"));
    const password = hash.digest("hex");

    let authResponse;

    if (isNewUser) {
      // Create new user
      authResponse = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: `Wallet ${walletAddress.substring(0, 6)}...${walletAddress.substring(38)}`,
          }
        }
      });
      
      // Also register their wallet
      if (authResponse.data.user) {
        const { error: insertError } = await supabase.from("wallets").insert({
          profile_id: authResponse.data.user.id,
          wallet_address: walletAddress.toLowerCase(),
          wallet_type: "eoa",
          currency: "USDC",
          balance: 0
        });
        if (insertError) console.error("Error inserting wallet record:", insertError);
      }
    } else {
      // Sign in existing user
      authResponse = await supabase.auth.signInWithPassword({
        email,
        password,
      });
    }

    if (authResponse.error) {
      console.error("Supabase auth failed:", authResponse.error.message);
      return NextResponse.json(
        { error: `Login failed: ${authResponse.error.message}` },
        { status: 401 }
      );
    }

    return NextResponse.json({
      success: true,
      message: "Logged in successfully",
      user: authResponse.data.user,
    });
  } catch (error: any) {
    console.error("Error in wallet-login route:", error);
    return NextResponse.json(
      { error: `Internal server error: ${error.message}` },
      { status: 500 }
    );
  }
}
