/**
 * Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { type NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/utils/supabase/server";
import { createHash } from "crypto";

export async function POST(req: NextRequest) {
  try {
    const { credential } = await req.json();

    if (!credential || !credential.id) {
      return NextResponse.json(
        { error: "Credential ID is required for verification." },
        { status: 400 }
      );
    }

    const supabase = await createClient();

    // Query all wallets to find a matching passkey credential ID
    const { data: wallets, error: walletsError } = await supabase
      .from("wallets")
      .select("profile_id, passkey_credential, wallet_address");

    if (walletsError || !wallets) {
      console.error("Error fetching wallets:", walletsError);
      return NextResponse.json(
        { error: "Authentication failed. No wallets found in database." },
        { status: 401 }
      );
    }

    // Find the wallet whose passkey_credential contains our credential.id
    const matchingWallet = wallets.find((w) => {
      try {
        if (!w.passkey_credential) return false;
        const cred = JSON.parse(w.passkey_credential);
        return cred.id === credential.id;
      } catch (e) {
        return false;
      }
    });

    if (!matchingWallet) {
      return NextResponse.json(
        { error: "Passkey is not registered. Please sign up or register this wallet first." },
        { status: 401 }
      );
    }

    // Reconstruct the deterministic email and password
    const walletAddress = matchingWallet.wallet_address;
    const email = `wallet_${walletAddress.toLowerCase()}@arcpay.passkey`;

    // Calculate deterministic secure password
    const hash = createHash("sha256");
    hash.update(credential.id + (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "arcpay_salt"));
    const password = hash.digest("hex");

    // Perform Supabase authentication
    const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError) {
      console.error("Supabase sign in failed:", signInError.message);
      return NextResponse.json(
        { error: `Login failed: ${signInError.message}` },
        { status: 401 }
      );
    }

    return NextResponse.json({
      success: true,
      message: "Logged in successfully",
      user: signInData.user,
    });
  } catch (error: any) {
    console.error("Error in passkey-login route:", error);
    return NextResponse.json(
      { error: `Internal server error: ${error.message}` },
      { status: 500 }
    );
  }
}
